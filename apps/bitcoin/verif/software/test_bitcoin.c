#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <poll.h>
#include <malloc.h>


#include <utils/sh_dpi_tasks.h>
#ifdef SV_TEST
# include <fpga_pci_sv.h>
#else
# include <fpga_pci.h>
# include <fpga_mgmt.h>
# include "fpga_dma.h"
# include <utils/lcd.h>
#endif

void print_status();
void initialize_inputs(uint32_t header, uint32_t target);
void trigger_start();
void wait_for_done();

void test_main(uint32_t *exit_code){
  int rc;
  int slot_id = 0;

  /* initialize the fpga_plat library */
  rc = fpga_mgmt_init();
  fail_on(rc, out, "Unable to initialize the fpga_mgmt library");

  print_status();


  initialize_inputs(0, 8);
  //Trigger start
  trigger_start();

  //Wait for done
  wait_for_done();


out:
  *exit_code = 0;
}


void print_status(){
  uint32_t status_base_addr = 0x0600;
  uint32_t read_data;
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;


  for(int i = 0; i < 16; i++){
   fpga_pci_peek(pci_bar_handle, status_base_addr + (i*4), &read_data);
   printf("R%d: 0x%x; ", i, read_data);
  }
  printf("\n");
  return;
}

void initialize_inputs(uint32_t header, uint32_t target){
  uint32_t control_base_addr = 0x500;

  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;
  fpga_pci_poke(pci_bar_handle, control_base_addr + 4, header);
  fpga_pci_poke(pci_bar_handle, control_base_addr + 8, target);
}

void trigger_start(){
  uint32_t control_base_addr = 0x0500;

  uint32_t write_data = 0x00000001;
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

  fpga_pci_poke(pci_bar_handle, control_base_addr, write_data);

}

void wait_for_done(){
  uint32_t done_base_addr = 0x0600;
  uint32_t read_data;
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

  printf("Waiting for done\n");

  int i = 0;
  fpga_pci_peek(pci_bar_handle, done_base_addr, &read_data);
  while( read_data == 0 ){
    if(i % 100 == 0){
      print_status();
    }
    fpga_pci_peek(pci_bar_handle, done_base_addr, &read_data);
    i++;
  }
  print_status();
  printf("DONE!");
  return;

}
