#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <poll.h>
#include <malloc.h>
#include <sys/time.h>


#include <fpga_pci.h>
#include <fpga_mgmt.h>
#include "fpga_dma.h"
#include <utils/lcd.h>

int check_slot_config(int slot_id);
void print_status(pci_bar_handle_t* pci_bar_handle);
void trigger_start(pci_bar_handle_t* pci_bar_handle);
void wait_for_done(pci_bar_handle_t* pci_bar_handle);

static const uint16_t AMZ_PCI_VENDOR_ID = 0x1D0F;
static const uint16_t PCI_DEVICE_ID = 0xF000;



int check_slot_config(int slot_id){
    int rc;
    struct fpga_mgmt_image_info info = {0};

    /* get local image description, contains status, vendor id, and device id */
    rc = fpga_mgmt_describe_local_image(slot_id, &info, 0);
    fail_on(rc, out, "Unable to get local image information. Are you running "
        "as root?");

    /* check to see if the slot is ready */
    if (info.status != FPGA_STATUS_LOADED) {
        rc = 1;
        fail_on(rc, out, "Slot %d is not ready", slot_id);
    }

    /* confirm that the AFI that we expect is in fact loaded */
    if (info.spec.map[FPGA_APP_PF].vendor_id != AMZ_PCI_VENDOR_ID ||
        info.spec.map[FPGA_APP_PF].device_id != PCI_DEVICE_ID)
    {
        rc = 1;
        char sdk_path_buf[512];
        char *sdk_env_var;
        sdk_env_var = getenv("SDK_DIR");
        snprintf(sdk_path_buf, sizeof(sdk_path_buf), "%s",
            (sdk_env_var != NULL) ? sdk_env_var : "<aws-fpga>");
        log_error(
            "...\n"
            "  The slot appears loaded, but the pci vendor or device ID doesn't match the\n"
            "  expected values. You may need to rescan the fpga with \n"
            "    fpga-describe-local-image -S %i -R\n"
            "  Note that rescanning can change which device file in /dev/ a FPGA will map to.\n",
            slot_id);
        log_error(
            "...\n"
            "  To remove and re-add your xdma driver and reset the device file mappings, run\n"
            "    sudo rmmod xdma && sudo insmod \"%s/sdk/linux_kernel_drivers/xdma/xdma.ko\"\n",
            sdk_path_buf);
        fail_on(rc, out, "The PCI vendor id and device of the loaded image are "
                         "not the expected values.");
    }

    char dbdf[16];
    snprintf(dbdf,
                  sizeof(dbdf),
                  PCI_DEV_FMT,
                  info.spec.map[FPGA_APP_PF].domain,
                  info.spec.map[FPGA_APP_PF].bus,
                  info.spec.map[FPGA_APP_PF].dev,
                  info.spec.map[FPGA_APP_PF].func);
    log_info("Operating on slot %d with id: %s", slot_id, dbdf);

out:
    return rc;

}


int main(int argc, char** argv){
  int rc;
  int slot_id = 0;
  int i;
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

  struct timeval t1, t2;
  double elapsed_time;

  /* initialize the fpga_plat library */
  rc = fpga_mgmt_init();
  fail_on(rc, out, "Unable to initialize the fpga_mgmt library");

  rc = check_slot_config(slot_id);
  fail_on(rc, out, "Slot config not correct");


  rc = fpga_pci_attach(slot_id, FPGA_APP_PF, APP_PF_BAR0, 0, &pci_bar_handle);
  fail_on(rc, out, "Failed to attach pci");

  //open dma
  int write_fd = -1;
  int read_fd = -1;

  read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id,
      0, true);
  fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open dma read");
  write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id,
      0, false);
  fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open dma rwrite");

  

  print_status(&pci_bar_handle);


  //Load the data
  printf("Initializing read data\n");
  uint64_t base_addr = 16777216;// 135106448 - 16;
  size_t len = 593472;
  //size_t len = 64;
  uint8_t* write_buffer = malloc(4096);


  //Layer 1
  printf("Writing read write\n");
  for(i = 0; i < 4096; i++){
    write_buffer[i] = 0;
  }

  size_t offset = 0;
  while(offset < len){
    size_t bytes_to_write;
    size_t bytes_remaining = len - offset;

    printf("offset: %d\n ",(int)offset);

    if( bytes_remaining > 4096 ){
      bytes_to_write = 4096;
    }
    else{
      bytes_to_write = bytes_remaining % 4096;
    }
    rc = fpga_dma_burst_write(write_fd, write_buffer, bytes_to_write, base_addr + offset);
    fail_on(rc, out, "Dma write failed");

    offset += bytes_to_write;
  }

  //weights
  printf("initializeing weights\n");

  base_addr = 0;
  len = 888720;

  // for(i = 0; i < len; i++){
  //   write_buffer[i] = 0;
  // }
  offset = 0;
  while(offset < len){
    size_t bytes_to_write;
    size_t bytes_remaining = len - offset;

    printf("offset: %d\n ",(int)offset);

    if( bytes_remaining > 4096 ){
      bytes_to_write = 4096;
    }
    else{
      bytes_to_write = bytes_remaining % 4096;
    }
    rc = fpga_dma_burst_write(write_fd, write_buffer, bytes_to_write, base_addr + offset);
    fail_on(rc, out, "Dma write failed");

    offset += bytes_to_write;
  }
  //rc = fpga_dma_burst_write(write_fd, weight_buffer, len, base_addr);
  //fail_on(rc, out, "Dma wweight failed");

  //Trigger start
  gettimeofday(&t1, NULL);
  trigger_start(&pci_bar_handle);

  //Wait for done
  wait_for_done(&pci_bar_handle);
  gettimeofday(&t2, NULL);

  elapsed_time = (t2.tv_sec - t1.tv_sec) * 1000000.0; //sec to us
  elapsed_time += (t2.tv_usec - t1.tv_usec);

  printf("Elapsed time: %f us", elapsed_time);


  //print output
  //printf("Reading output\n");
  //base_addr = 135699920;
  //len = 160+16;

  //uint8_t* read_buffer = malloc(len);

  //rc = fpga_dma_burst_read(read_fd, read_buffer, len, base_addr);
  //fail_on(rc, out, "Dma read failed");
  //
  //printf("0x");
  //for(int i = 0; i < len; i++){
  //  printf("%d: %x \n", i, read_buffer[i]);
  //}

  printf("DONE!:");



  //free(weight_buffer);
  free(write_buffer);
  //free(read_buffer);



out:
  if(pci_bar_handle >= 0){
    fpga_pci_detach(pci_bar_handle);
  }
  return 0;
}


void print_status(pci_bar_handle_t* pci_bar_handle){
  uint32_t status_base_addr = 0x0600;
  uint32_t read_data;


  for(int i = 0; i < 16; i++){
   fpga_pci_peek(*pci_bar_handle, status_base_addr + (i*4), &read_data);
   printf("R%d: 0x%x; ", i, read_data);
  }
  printf("\n");
  return;
}


void trigger_start(pci_bar_handle_t* pci_bar_handle){
  uint32_t control_base_addr = 0x0500;

  uint32_t write_data = 0x00000001;

  fpga_pci_poke(*pci_bar_handle, control_base_addr, write_data);

}

void wait_for_done(pci_bar_handle_t* pci_bar_handle){
  uint32_t done_base_addr = 0x0604;
  uint32_t read_data;

  printf("Waiting for done\n");

  int i = 0;
  fpga_pci_peek(*pci_bar_handle, done_base_addr, &read_data);
  while( read_data == 0 ){
    if(i % 100 == 0){
      print_status(pci_bar_handle);
    }
    fpga_pci_peek(*pci_bar_handle, done_base_addr, &read_data);
    i++;
  }
  print_status(pci_bar_handle);
  printf("DONE!");
  return;

}
