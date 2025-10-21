from Crypto.Cipher import AES
from Crypto.Hash import CMAC
from Crypto.Hash import SHA256
import binascii
import argparse
import hashlib
import json

##########################################################################
# HASHED CMACS GENERATION
##########################################################################

parser = argparse.ArgumentParser(
    prog='CMAC Generator',
    description='Generate CMAC hashes for NFC authentication'
)

parser.add_argument('-k', '--key', required=True, type=str, help='The key to use for the SDMMAC')
parser.add_argument('-u', '--uid', required=True, type=str, help='The UID to use for the SDMMAC')
parser.add_argument('-c', '--count', default=42000, type=int, help='The count value')
parser.add_argument('-o', '--output', required=True, type=str, help='Output JSON file path')

def decode(hex_str):
    return binascii.unhexlify(hex_str)

def encode(bytes_str):
    return binascii.hexlify(bytes_str).decode().upper()

def SDMMAC(count, uid, mKey):
    cmac = CMAC.new(decode(mKey), ciphermod=AES)
    sv1 = "3CC300010080" + uid + count
    cmac.update(decode(sv1))
    k1 = encode(cmac.digest())
    
    fullSDMMAC = CMAC.new(decode(k1), ciphermod=AES)
    fullSDMMAC.update(b'')
    
    fullString = encode(fullSDMMAC.digest())
    
    s1 = fullString[2:4]
    s2 = fullString[6:8]
    s3 = fullString[10:12]
    s4 = fullString[14:16]
    s5 = fullString[18:20]
    s6 = fullString[22:24]
    s7 = fullString[26:28]
    s8 = fullString[30:32]
    
    return (s1 + s2 + s3 + s4 + s5 + s6 + s7 + s8).upper()

def int_to_little_endian_3byte_hex(num):
    hex_string = format(num, '06x')
    return ''.join(reversed([hex_string[i:i+2] for i in range(0, len(hex_string), 2)]))

def generate_hashes(count, uid, key):
    return [hashlib.sha256(SDMMAC(int_to_little_endian_3byte_hex(i), uid, key).encode('utf-8')).hexdigest() 
            for i in range(1, count)]

def main():
    args = parser.parse_args()
    
    if len(args.key) != 32:
        print("Key must be 32 characters long")
        return

    hashes = generate_hashes(args.count, args.uid, args.key)
    
    # Save hashes to JSON file
    with open(args.output, 'w') as f:
        json.dump(hashes, f)
    
    print(f"Generated {len(hashes)} hashes and saved to {args.output}")

if __name__ == "__main__":
    main()