#!/usr/bin/python
import serial
import os
import sys
import hashlib
from Crypto.Cipher import AES
import Crypto.Random
from Crypto.Hash import SHA3_384
from Crypto.Hash import SHA3_256


# Constant definitions
UART_PACKET_HEADER_SIZE = 3
UART_PACKET_MAX_SIZE = 255
UART_CMD_ACK    =     0x01
UART_CMD_SYN    =     0x02
UART_CMD_SYNACK =     0x03
UART_CMD_NACK   =     0x04
UART_CMD_PUSH_USER_PK = 0x05
UART_CMD_PULL_FPGA_PK = 0x06
UART_CMD_CALC_FPGA_SS = 0x07
UART_CMD_PULL_FPGA_PK_SIG = 0x08
UART_CMD_PULL_BITSTREAM_SIG = 0x09
UART_CMD_PUSH_FPGA_DATA = 0x0a
UART_CMD_PUSH_USER_NONCE = 0x0b
UART_CMD_PULL_ATTESTATION = 0x0c
UART_CMD_PUSH_BITSTREAM_KEY = 0x0d

#Files
my_key_file = "../keys/key.bin"
attestation_key_file = "../keys/fpga_pk.bin"
attestation_key_signature_file = "../keys/fpga_pk_sig.bin"
shared_secret_file = "../keys/shared_secret.bin"
bitstream_signature_file = "../keys/bitstream_sig.bin"
bitstream_hash_file = "../keys/bitstream_hash.bin"
bitstream_file = "../bitstream/bitstr.bin"
ed25519_file = "../bin/ed25519"
attestation_report_file = "../keys/attestation_report.bin"
attestation_sig_file = "../keys/attestation_sig.bin"
shared_secret_sig_file = "../keys/shared_secret_sig.bin"

#Root public key
root_mod = 0xc03658d5059ff69f8cb29a9c3668b82a28c4364d4e33cedbcf2bdd38da01dc11f94aba6a70ebe1c048c4a72143a466f5c0db746ef3d8fe6f424b1c13400ef56ea1138d454ffc3e0ae24883bc2dbd79f1e242bc036b5c111d386627bf7c551d7ae001d68c15cbe7a787f1792d23ab20182d071a04236f5255cc6dd38ddbce832471cac0caa0caceb57c261c3c3eaabeed1682e75a6b7574e5ffcecfea9995287f340ca60bb82b09007a15b905cb13a794ea0e0411e5fbb0d3a87c687fb6f9cd62671ab6fd849dceb9998360e29533438dba50c4296f33388831514fc9be260480fab39ddb72ab7c98010acc8a043c2a8f395b2d7c78716fc25fc83ed4c155a7d9962d08c00a995487736c9b6b65c2d98b1cc2629bad4981aa02c24f7bc1e6094ce09d05f1601288aa6baad7b440c7a25337cb22cd890dc16b24697f8bcd0752a3a468e7c5dd9c841aa4a3da3b4dd7af5ee3696c764bf8a7d4a69c998f87850cd5fb18662b0798389a013f4e3256be0cf65a7a43129e0c5944aaf82001c4599d64c8ccfef984215663178d6c2ede369709728ed0e2e3bd18292d3bf9430a50b54de9b79371768af7523aec03d05c2fce7a7eb831c0856baf77da792220c2d643912ea9313ac876ded97dc2de2a8ec50e25962e31ecff0d3b0f8e8381e7be83b6cd9b49ade86cea0ac523fd626732e51dbe6a6120cf08df6e1ae517576bf0782bd5

root_pub_exp = 65537

"""
Writes a packet to the FPGA.

@param packet_body: A bytearray containing the body of the packet
@param ser: serial terminal
@param cmd: header command

@return 0 on success
"""
def fpga_write_packet(ser, packet_body, cmd, metadata):
    body_len = len(packet_body)
    #Check for overflow
    if(body_len + UART_PACKET_HEADER_SIZE > UART_PACKET_MAX_SIZE):
        print("ERROR: Failed to write packet - too large")
        return -1
    
    #Initialize packet and params
    packet = bytearray()
    packet_len = UART_PACKET_HEADER_SIZE + body_len

    #Write the header
    packet.append(cmd)
    packet.append(metadata)
    packet.append(packet_len & 0xff)

    #Write the rest of the body.
    packet.extend(packet_body)

    #Send it out through UART
    if(ser.write(packet) != packet_len):
        return -1

    return 0

"""
Read a packet from the FPGA
Returns a tuple (cmd, packet_body)

Blocks until the entire packet is read.

"""
def fpga_read_packet(ser):
    header = ser.read(size=3)

    #Split up the header
    cmd = header[0]
    packet_meta = header[1]
    packet_len = header[2]
    body_len = packet_len - UART_PACKET_HEADER_SIZE

    #Expect packet_len - header more bytes
    if(body_len > 0):
        body = ser.read(size=body_len)
    else:
        body = bytearray()

    #return the tuple
    return (cmd, packet_meta, body)

"""
This function is called when an ACK is expected back from the FPGA
Returns 0 on success
"""
def fpga_verify_ack(ser):
    (cmd, meta, packet_body) = fpga_read_packet(ser)
    
    if(cmd == UART_CMD_ACK):
        return
    else:
        raise Exception("ACK not received from FPGA")

"""
Send an ACK to the FPGA
"""
def fpga_send_ACK(ser):
    status = fpga_write_packet(ser, bytearray(), UART_CMD_ACK, 0)
    if(status !=0):
        print("ERROR: Unable to send ACK")

"""
Print a simple header for demo
"""
def print_header():
    print("=============================================================")


"""
Establish a connection with the security monitor of the FPGA.
This program acts as the client in a 3-way handshake.

Thus, send a SYN, receive an SYNACK, and finally send an ACK to establish
the connection.

"""
def fpga_sync(ser):
    print("Establishing a session with the FPGA...")
    #send SYN
    status = fpga_write_packet(ser, bytearray(), UART_CMD_SYN, 0)
    if(status != 0):
        print("ERROR: Unable to send SYN command")
    else:
        print("Sent SYN")

    #expect back SYNACK
    (cmd, meta, body) = fpga_read_packet(ser)

    if(cmd != UART_CMD_SYNACK):
        print("ERROR: Received invalid command")
        return -1
    else:
        print("Received SYNACK")

    #Send ACK
    status = fpga_write_packet(ser, bytearray(), UART_CMD_ACK, 0)
    if(status !=0):
        print("ERROR: Unable to send ACK")
    else:
        print("Sent ACK")

    print("Session established done")
    return 0

"""
Read and print out all incoming serial data until a timeout
"""
def stream_uart(ser, timeout):
    print("Waiting for device boot...")
    ser.timeout = timeout
    while True:
        byte = ser.read_until()
        if(len(byte) == 0):
            input("Press Enter to begin...")
            ser.timeout = None #no more timeout on reads
            return
        try:
            print(byte.decode("ascii"))
        except:
            continue


"""
Send my ed25519 public key to the remote FPGA
"""
def fpga_send_pk(ser, my_pk):
    print_header()
    if(len(my_pk) != 32):
        raise Exception("Invalid PK")
    print("Sending the remote FPGA my public key 0x" + my_pk.hex())

    #Send to the FPGA
    status = fpga_write_packet(ser, my_pk, UART_CMD_PUSH_USER_PK, 0)

    if(status != 0):
        raise Exception("Unable to send FPGA my PK")

    #Expect back an ACK from the FPGA
    fpga_verify_ack(ser)

    return

def fpga_send_nonce(ser, nonce):
    """
    Send nonce to the remote fpga. Nonce will be signed by FPGA and verified
    at a later point
    """
    status = fpga_write_packet(ser, nonce, UART_CMD_PUSH_USER_NONCE, 0)
    if(status != 0):
        raise Exception("Unable to send FPGA my nonce")

    #Expect back ACK from FPGA
    fpga_verify_ack(ser)

    return

def fpga_get_attestation(ser):
    """
    Get the attestation report generated by the FPGA
    """
    print_header()
    print("Retreiving attestation report from FPGA...")

    attestation = bytearray()

    status = fpga_write_packet(ser, [], UART_CMD_PULL_ATTESTATION, 0)
    if(status != 0):
        raise Exception("Unable to send PULL ATTESTATION command")

    #Wait for attestation report of size 752 bytes
    bytes_read = 0
    while(bytes_read < 752):
        (response_cmd, metadata, response_body) = fpga_read_packet(ser)
        print(type(metadata))
        print(type(response_cmd))

        if(response_cmd != UART_CMD_PULL_ATTESTATION or metadata != bytes_read/4):
            print(response_cmd)
            print(metadata)
            raise Exception("Error in reading attestation")

        fpga_send_ACK(ser)

        attestation.extend(response_body)
        bytes_read = bytes_read + len(response_body)

    print("FPGA Attestation is 0x" + attestation.hex())

    return attestation

def parse_attestation(attestation):
    """
    Given a bytes of the attestation report of length 688, return a dict
    of each field of the report
    """
    assert(len(attestation) == 752)

    parsed_report = {}

    parsed_report['nonce']       = attestation[:32]
    parsed_report['attest_pk']   = attestation[32:64]
    parsed_report['kernel_hash'] = attestation[64:112]
    parsed_report['kernel_sig']  = attestation[112:624]
    parsed_report['attest_sig']  = attestation[624:688]
    parsed_report['shared_secret_sig'] = attestation[688:]
    
    return parsed_report

def verify_kernel_certificate(certificate_hash, signature):
    """
    Given SHA3-384(kernel_hash || attest_pk) and a 512-byte
    RSA PKCS#1.5 signature of the hash, return true if the signature
    is verified against the trusted public root key
    """

    #Decrypt the signature with the root public key
    sig_int = int.from_bytes(signature, byteorder='big', signed=False)
    sig_decrypted = pow(sig_int, root_pub_exp, root_mod)

    #Convert decrypted to bytearray
    sig_decrypted_string = hex(sig_decrypted)

    #The hash is contained in the last 48 bytes of the signature
    sig_decrypted_hash = sig_decrypted_string[-96:]

    if(sig_decrypted_hash == certificate_hash):
        return True
    else:
        return False

def verify_attestation_report(attestation):
    """
    Given the attestation report, return True if the attestation
    report is signed by the secret attestation key corresponding
    to the public attestation key in the report
    """

    #Write the attestation PK to a file
    with open(attestation_key_file, mode="wb") as outfile:
        outfile.write(attestation['attest_pk'])

    #Write the entire report (minus the signature and the shared secret sig) to a file
    with open(attestation_report_file, mode="wb") as outfile:
        outfile.write(attestation['nonce'])
        outfile.write(attestation['attest_pk'])
        outfile.write(attestation['kernel_hash'])
        outfile.write(attestation['kernel_sig'])

    #Write the signature on the report to a file
    with open(attestation_sig_file, mode="wb") as outfile:
        outfile.write(attestation['attest_sig'])

    #Verify that the signature on the report is valid
    cmd = ed25519_file + " -v " + attestation_key_file + " " + attestation_sig_file + " " + attestation_report_file + " " + str(624)

    return (os.system(cmd) == 0)
    
def verify_attestation(attestation, nonce):
    """
    Given a bytes of the attestation report, return if the report is verified.
    Otherwise, throw an exception.

    nonce: Random nonce generated as a challenge to the FPGA
    """

    print_header()
    print("Verifying atttestation report...")
    
    #Parse the bytes of the attestation into a dict
    parsed_report = parse_attestation(attestation)

    
    #Verify Nonce
    if(parsed_report['nonce'] != nonce):
        raise Exception("Attestation Failed")

    #TODO: Verify the security kernel hash from a list of trusted hashes

    #Hash the kernel hash + attestation PK together
    h_obj = SHA3_384.new()
    h_obj.update(parsed_report['kernel_hash'])
    h_obj.update(parsed_report['attest_pk'])

    kernel_cert_hash = h_obj.hexdigest()

    #Verify that the trusted Public Root Key signed the kernel certificate hash
    if(not verify_kernel_certificate(kernel_cert_hash, parsed_report['kernel_sig'])):
        raise Exception("Attestation Failed")

    #At this stage, trust is established in the security kernel and the attestation public key
    #Verify that the attestation report is signed with the secret attestation key
    if(not verify_attestation_report(parsed_report)):
        raise Exception("Attestation Failed")


    return

def fpga_key_exchg(attestation):
    """
    Perform key exchange with the remote FPGA.

    Throws an error if the key exchange is not authenticated by the FPGA

    return: a bytes object of the shared AES key.
    """
    print_header()
    print("Performing key exchange...")

    parsed_attestation = parse_attestation(attestation)

    #Write the attestation public key to a file
    with open(attestation_key_file, "wb") as outfile:
        outfile.write(parsed_attestation['attest_pk'])

    #Call an external C program to calculate the SS
    cmd = ed25519_file + " -x " + my_key_file + " " + attestation_key_file + " " + shared_secret_file
    os.system(cmd)

    #Write the shared secret signature to a file
    with open(shared_secret_sig_file, "wb") as outfile:
        outfile.write(parsed_attestation['shared_secret_sig'])

    #Verify if the shared secret is properly signed
    cmd = ed25519_file + " -v " + attestation_key_file + " " + shared_secret_sig_file + " " + shared_secret_file + " " + str(32)

    if(os.system(cmd) != 0):
        raise Exception("Shared Secret not verified\r\n")

    #Read in the shared secret
    with open(shared_secret_file, "rb") as ssfile:
        shared_secret = ssfile.read(32)
        print("Generated shared secret " + shared_secret.hex())
    
    #Hash the shared secret to obtain the shared AES key.
    h_obj = SHA3_256.new()
    h_obj.update(shared_secret)
    session_key = h_obj.digest()

    print('Session Key: ' + h_obj.hexdigest())

    return session_key

def fpga_send_bitstream_key(ser, session_key, bitstream_key):
    """
    Encrypt the bitstream key with the session key, and send the encrypted bitstream key
    to the FPGA

    session_key: bytes object with length 32 containing session key with FPGA
    bitstream_key: bytes object with length 32 containing key used to encrypt the bitstream
    ser: serial object
    """
    assert(len(session_key) == 32 and len(bitstream_key) == 32)
    
    #12-byte random nonce
    rand_nonce = Crypto.Random.get_random_bytes(12)

    cipher = AES.new(session_key, AES.MODE_GCM, nonce=rand_nonce)
    ciphertext, tag = cipher.encrypt_and_digest(bitstream_key)

    msg = bytearray()

    msg.extend(rand_nonce)
    msg.extend(tag)
    msg.extend(ciphertext)

    #message should be 12+16+32 = 60 bytes long
    assert(len(msg) == 60)

    status = fpga_write_packet(ser, msg, UART_CMD_PUSH_BITSTREAM_KEY, 0)
    if(status != 0):
        raise Exception("Unable to send bitstream key")

    #Expect back ACK from FPGA
    fpga_verify_ack(ser)

    return

"""
Pull the FPGA's ed25519 public key and read it

Returns a bytes object of the FPGA's public key.
"""
def fpga_get_pk(ser):
    print_header()
    print("Retreiving the remote FPGA's public key...")

    status = fpga_write_packet(ser, [], UART_CMD_PULL_FPGA_PK, 0)
    if(status != 0):
        print("ERROR: Unable to issue PULL cmd")
        return None
    

    #Wait for the FPGA's public key.
    (response_cmd, metadata, response_body) = fpga_read_packet(ser)
    if(response_cmd != UART_CMD_PULL_FPGA_PK or len(response_body) != 32):
        print("Received invalid reply")
        return None

    fpga_send_ACK(ser)

    print("FPGA's public key is 0x" + response_body.hex())

    return response_body


"""
Get a signature of the hash of the user's bitstream from the FPGA.

The bitstream has been hashed via SHA3 and been signed with the attestation secret key.

"""
def fpga_get_bitstream_signature(ser):
    signature = bytearray();

    print_header()
    print("Retreiving the remote FPGA's signature of my bitstream...")
    
    status = fpga_write_packet(ser, [], UART_CMD_PULL_BITSTREAM_SIG, 0)
    if(status != 0):
        print("ERROR: Unable to issue PULL cmd")
        return None

    (response_cmd, metadata, response_body) = fpga_read_packet(ser)
    if(response_cmd != UART_CMD_PULL_BITSTREAM_SIG or len(response_body) != 64):
        print("Received invalid reply")
        return None

    signature.extend(response_body)

    fpga_send_ACK(ser)

    print("Signature of my bitstream hash is 0x" + signature.hex())

    return signature

"""
Given a bitstream file, and a file containing the bitstream signature,
return True if the signature and the bitstream verify, or False otherwise.
"""
def verify_bitstream_signature():
    print_header()
    print("Verifying bitstream signature...")

    bitstream_hash = hashlib.sha3_384()
    with open(bitstream_file, mode="rb") as infile:
        bitstream_data = infile.read()
        bitstream_hash.update(bitstream_data)
  
    bitstream_hash_string = bitstream_hash.hexdigest()
    print("Calculated LOCAL bitstream SHA3 digest 0x" + bitstream_hash_string)
    bitstream_hash_bytes = bytes.fromhex(bitstream_hash_string)

    #Write to output file
    with open(bitstream_hash_file, mode="wb") as outfile:
        outfile.write(bitstream_hash_bytes)

    print("Decrypting bitstream signature with attestation public key and verifying against local hash...")
    
    #Verify that the bitstream signature matches the bitstream hash.
    cmd = ed25519_file + " -v " + attestation_key_file + " " + bitstream_signature_file + " " + bitstream_hash_file
    bitstream_match = (os.system(cmd) == 0)

    if(bitstream_match):
        return True
    else:
        return False

"""
Return true if the received attestation key is verified against
the received signature.
"""
def verify_attestation_signature():
    print_header()
    print("Verifying attestation key signature...")

    ak_sig = bytearray()

    #Read in the attestation key signature.
    with open(attestation_key_signature_file, mode="rb") as sigfile:
        sig = sigfile.read(512)

    ak_sig.extend(sig)

    #Decrypt the signature with the root public key.
    ak_sig_int = int.from_bytes(ak_sig, byteorder='big', signed=False)
    ak_sig_decrypted = pow(ak_sig_int, root_pub_exp, root_mod)

    #Convert decrypted to bytearray.
    ak_sig_decrypted_string = hex(ak_sig_decrypted)

    #Read in the given public attestation key.
    ak_hash = hashlib.sha3_384()
    with open(attestation_key_file, mode="rb") as akfile:
        ak_hash.update(akfile.read(32))

    ak_hash_string = ak_hash.hexdigest()

    #Compare the decrypted signature and the generated hash
    ak_sig_decrypted_hash = ak_sig_decrypted_string[-96:]

    attestation_verified = ak_sig_decrypted_hash == ak_hash_string

    print("Decrypted signature with public ROOT key 0x" + ak_sig_decrypted_string)
    print("Signed public attestation key SHA3 hash is 0x" + ak_sig_decrypted_hash)
    print("Received public attestation key SHA3 hash is 0x" + ak_hash_string)

    if(attestation_verified):
        return True
    else:
        return False

"""
Send FPGA data for it to process. For now, it should be a 32-bit number, which
the FPGA will add 1 to and send back a result in a following packet
"""
def fpga_send_data(ser, user_input):
    if(len(user_input) != 16):
        print("ERROR: Improperly formatted data")
        return None

    status = fpga_write_packet(ser, user_input, UART_CMD_PUSH_FPGA_DATA, 0)
    if(status != 0):
        print("ERROR: Unable to issue PUSH cmd")
        return None
    
    #Expect back an ACK from the FPGA
    status = fpga_verify_ack(ser)
    if(status != 0):
        return -1

    return 0

"""
Wait for an encrypted nonce to come back...
"""
def fpga_get_data(ser):
    result = bytearray();

    (response_cmd, metadata, response_body) = fpga_read_packet(ser)
    #Metadata states which is a 16 byte chunk of the signature the packet holds
    if(len(response_body) != 16 or response_cmd != UART_CMD_PUSH_FPGA_DATA):
        print("Received invalid reply")
        return None

    #Send an ACK
    fpga_send_ACK(ser)

    return response_body


def main():
    #Open a connection with the UART termina
    if (len(sys.argv) != 2):
        print("ERROR: Need to specify UART device");
        return
    ser = serial.Serial(sys.argv[1], baudrate=115200)
    print("Opened port to FPGA:");
    print(ser.name)

    #Stream in data from FPGA until boot process is done
    stream_uart(ser, 10)

    #Establish a connection to the security monitor
    status = fpga_sync(ser)
    if(status != 0):
        return

    ##Read in my public key and send it to the FPGA
    input("Press ENTER to continue...")
    with open(my_key_file, "rb") as keyfile:
        my_pk = keyfile.read(32)
        fpga_send_pk(ser, my_pk)
    
    #Generate a random nonce and send it to the FPGA
    input("Press ENTER to continue...")
    nonce = Crypto.Random.get_random_bytes(32)
    fpga_send_nonce(ser, nonce)
    print("Nonce is: " + nonce.hex())
    
    #TODO: Remove this after removing prints on FPGA
    stream_uart(ser,5)

    #Get the attestation from the FPGA
    attestation_report = fpga_get_attestation(ser)

    input("Press ENTER to continue...")
    try:
        verify_attestation(attestation_report, nonce)
    except:
        raise

    #The attestation is verified. Perform key exchange with the FPGA
    try:
        session_key = fpga_key_exchg(attestation_report)
    except:
        raise

    #Encrypt the bitstream decryption key with the session key
    #KEEP THIS SECRET: (i.e. don't distribute this code)
    #Or generate a new key after establishing session....
    #For demo purposes this is okay for now..
    bitstream_key = bytes.fromhex("F878B838D8589818E868A828C8488808F070B030D0509010E060A020C0408000")

    fpga_send_bitstream_key(ser, session_key, bitstream_key)
    
    #Wait for the bitstream to be programmed onto the FPGA
    stream_uart(ser, 10);







    #input("Press ENTER to continue...")
    #fpga_pk = fpga_get_pk(ser)
    #if(fpga_pk is None):
    #    return

    ##Instruct the FPGA to calculate the shared secret
    #input("Press ENTER to continue...")
    #shared_secret = fpga_key_exchg(ser, fpga_pk)
    #if(shared_secret is None):
    #    return

    ##Retreive signatures from the FPGA...
    ##To build the root of trust, we start at the root RK
    ##Which then proves the attestation PK
    ##Which then proves the bitstream signature
    #input("Press ENTER to begin signature verification process...")
    #fpga_pk_sig = fpga_get_pk_signature(ser)
    #
    ##Write the attestation key signature to a file
    #with open(attestation_key_signature_file, "wb") as sigfile:
    #    sigfile.write(fpga_pk_sig)


    #input("Press ENTER to continue...")
    #bitstream_sig = fpga_get_bitstream_signature(ser)

    ##Write the bitstream signature to a file
    #with open(bitstream_signature_file, "wb") as sigfile:
    #    sigfile.write(bitstream_sig)

    #input("Press ENTER to continue...")

    ##Verify that my bitstream has been loaded correctly
    #bitstream_match = verify_bitstream_signature()

    #if(bitstream_match):
    #    print("Bitstream signature and local bitstream hash VERIFIED")
    #else:
    #    print("ERROR: Bitstream signature INVALID")
    #    return
    #
    #input("Press ENTER to continue...")
    #
    ##The bitstream hash is verified.
    ##We must trust the SIGNER of the bitstream signature to trust the verification.
    ##Thus, we have to now verify the attestation public key.
    #attestation_key_verified = verify_attestation_signature()

    #if(attestation_key_verified):
    #    print("Attestation key VERIFIED")
    #else:
    #    print("ERROR: Attestation key signature INVALID")
    #    return

    #print_header()
    print("Attestation process COMPLETE")
    input("Press ENTER to continue...")

    print_header()
    cek = '2b7e151628aed2a6abf7158809cf4f3c'
    key_bytes = bytes.fromhex(cek)
    cipher = AES.new(key_bytes, AES.MODE_ECB)
    print("Crypto Miner Feb. 5. 2019")
    print("Shield Configuration: CtrlReg (AES-128)")
    print("Channel Encryption Key: " + cek)
    input_hex = input("Enter a block header to mine on: 0x")
    input_data = bytes.fromhex(input_hex)
    input_ciphertext = cipher.encrypt(input_data)
    print("Sending encrypted block header: " + input_ciphertext.hex())

    fpga_send_data(ser, input_ciphertext)

    print("Mining on block header with difficulty = 24...")

    enc_result = fpga_get_data(ser)

    print("Received encrypted result: 0x" + enc_result.hex())
    print_header()
    print("Mining complete...")

    nonce = cipher.decrypt(enc_result)
    nonce_hex = nonce.hex()[16:]
    print("Decrypted nonce: 0x" + nonce_hex + " - decimal value: " + str(int(nonce_hex, 16)))

    solution = input_hex + nonce_hex

    target_hash = hashlib.sha256(bytearray.fromhex(solution)).hexdigest()
    print("Mined block hash: 0x" + target_hash)

    #input_data = bytes.fromhex("dead0000")
    #otp_pointer = 0
    #while otp_pointer <= 32-8:
    #    input_data = bytes.fromhex(input("Enter a hex number to send to the FPGA: 0x"))
    #    encrypted_data = bytearray()
    #    for x in range(4):
    #        encrypted_data.append(shared_secret[x + otp_pointer] ^ input_data[x])

    #    otp_pointer += 4
    #    print("Encrypting data with shared secret and sending to the FPGA 0x" + encrypted_data.hex())

    #    encrypted_result = fpga_send_data(ser, encrypted_data)

    #    print("Received encrypted result 0x" + encrypted_result.hex())

    #    #Decrypt the data
    #    decrypted_result = bytearray()
    #    decrypted_result.append((encrypted_result[0]) ^ shared_secret[otp_pointer])
    #    decrypted_result.append((encrypted_result[1]) ^ shared_secret[otp_pointer + 1])
    #    decrypted_result.append((encrypted_result[2]) ^ shared_secret[otp_pointer + 2])
    #    decrypted_result.append((encrypted_result[3]) ^ shared_secret[otp_pointer + 3])
    #    otp_pointer += 4
    #    
    #    print("Decrypted result: 0x" + decrypted_result.hex())

   
def test():
    gen_hash_file(bitstream_file, bitstream_hash_file)
    cmd = ed25519_file + " -v " + attestation_key_file + " " + bitstream_signature_file + " " + bitstream_hash_file
    print(os.system(cmd))


if __name__ == "__main__":
    main()