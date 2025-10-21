#!/usr/bin/env python3
import subprocess
import argparse
import json
from typing import Optional, Tuple
from ctypes import c_ubyte, c_uint, c_uint16, byref, memset, sizeof
import ntag424_programmer as ntp

##########################################################################
# URL ROUTE PROTECTION WITH NFC NTAG424 DNA tags
##########################################################################


def get_canister_name_from_dfx() -> Optional[str]:
    """Read dfx.json and get the canister name."""
    try:
        with open("dfx.json", "r") as f:
            dfx_config = json.load(f)
            for canister_name in dfx_config.get("canisters", {}):
                if canister_name != "internet_identity":
                    return canister_name
        return None
    except Exception as e:
        print(f"Error reading dfx.json: {str(e)}")
        return None


##########################################################################


def run_command(command: str) -> Tuple[int, str, str]:
    """Run a shell command and return its exit code, stdout, and stderr."""
    process = subprocess.Popen(
        command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    stdout, stderr = process.communicate()
    return process.returncode, stdout, stderr


##########################################################################


def setup_route_and_program(
    canister_id: str,
    page: str,
    params: str = None,
    use_random_key: bool = False,
    ic_mode: bool = False,
    cmac_count: int = 20000,
) -> bool:
    """Setup protected route and program NFC card."""
    try:
        # Get canister name from dfx.json
        canister_name = get_canister_name_from_dfx()
        if not canister_name:
            print("Error: Could not find canister name in dfx.json")
            return False
        print(f"Using canister name from dfx.json: {canister_name}")

        # Form the URI for the card based on environment
        if ic_mode:
            uri = f"https://{canister_id}.raw.icp0.io/{page}"
        else:
            uri = f"http://{canister_id}.raw.localhost:4943/{page}"
        print(f"Using URI: {uri}")

        # Start card programming following ntag424_programmer.py logic
        status = ntp.ReaderOpen()
        if status != 0:
            print(f"Error opening reader: {ntp.uFR_NT4H_Status2String(status)}")
            return False

        # Get card UID (following ntag424_programmer.py logic)
        uid = (c_ubyte * 11)()
        sak = c_ubyte()
        uid_size = c_ubyte()
        status = ntp.GetCardIdEx(sak, uid, uid_size)
        if status != 0:
            print(f"Error getting card ID: {ntp.uFR_NT4H_Status2String(status)}")
            return False

        card_uid = "".join(f"{uid[n]:02X}" for n in range(uid_size.value))
        print(f"Successfully got card UID: {card_uid}")

        # Form SDM NDEF Payload
        formed_result = ntp.form_sdm_ndef_payload(uri)
        print(f"Formed NDEF payload")

        # Get extended payload
        extended_payload_result = ntp.add_additional_ndef_payload_parameter(
            formed_result["sdm_payload"],
            params.split("=")[0] if params and "=" in params else "",
            params.split("=")[1] if params and "=" in params else "",
        )

        # Setup for writing
        default_key = (c_ubyte * 16)()
        memset(default_key, 0, sizeof(default_key))

        # Write SDM payload
        file_no = c_ubyte(2)
        key_no = c_ubyte(0)
        communication_mode = c_ubyte(0)
        status = ntp.nt4h_set_global_parameters(file_no, key_no, communication_mode)
        if status != 0:
            print(
                f"Error setting global parameters: {ntp.uFR_NT4H_Status2String(status)}"
            )
            return False

        write_data_buffer = (
            c_ubyte * len(extended_payload_result["extended_payload"])
        )(*extended_payload_result["extended_payload"])
        write_len = c_uint16(extended_payload_result["extended_payload_length"])
        bytes_written = c_uint16()
        auth_mode = c_ubyte(ntp.T4T_AUTHENTICATION["T4T_PK_PWD_AUTH"])

        status = ntp.LinearWrite_PK(
            write_data_buffer, 0, write_len, bytes_written, auth_mode, default_key
        )
        if status != 0:
            print(f"Error writing NDEF message: {ntp.uFR_NT4H_Status2String(status)}")
            return False
        print("NDEF Message written successfully")

        # Change SDM settings
        communication_mode = c_ubyte(3)
        new_communication_mode = c_ubyte(0)
        read_key_no = c_ubyte(0x0E)
        write_key_no = c_ubyte(0)
        read_write_key_no = c_ubyte(0)
        change_key_no = c_ubyte(0)
        uid_enable = c_ubyte(1)
        read_ctr_enable = c_ubyte(1)
        read_ctr_limit_enable = c_ubyte(0)
        enc_file_data_enable = c_ubyte(0)
        meta_data_key_no = c_ubyte(0x0E)
        file_data_read_key_no = c_ubyte(0)
        read_ctr_key_no = c_ubyte(0)
        picc_data_offset = c_uint(0)
        mac_input_offset = c_uint(formed_result["mac_offset"])
        enc_offset = c_uint(0)
        enc_length = c_uint(0)
        read_ctr_limit = c_uint(0)
        tt_status_enable = c_ubyte(0)
        tt_status_offset = c_uint(0)

        status = ntp.nt4h_tt_change_sdm_file_settings_pk(
            default_key,
            file_no,
            key_no,
            communication_mode,
            new_communication_mode,
            read_key_no,
            write_key_no,
            read_write_key_no,
            change_key_no,
            uid_enable,
            read_ctr_enable,
            read_ctr_limit_enable,
            enc_file_data_enable,
            meta_data_key_no,
            file_data_read_key_no,
            read_ctr_key_no,
            formed_result["uid_offset"],
            formed_result["read_ctr_offset"],
            picc_data_offset,
            mac_input_offset,
            enc_offset,
            enc_length,
            formed_result["mac_offset"],
            read_ctr_limit,
            tt_status_enable,
            tt_status_offset,
        )
        if status != 0:
            print(f"Error setting SDM settings: {ntp.uFR_NT4H_Status2String(status)}")
            return False
        print("SDM settings set successfully")

        if use_random_key:
            new_key_str = ntp.generate_random_aes_key_hex()
            new_key = ntp.string_to_hex_buffer(new_key_str)
            status = ntp.nt4h_change_key_pk(default_key, 0, new_key, default_key)
            if status != 0:
                print(
                    f"Error changing master key: {ntp.uFR_NT4H_Status2String(status)}"
                )
                return False
            print(f"Master key changed successfully to: {new_key_str}")
            cmd = f"python3 scripts/hashed_cmacs.py -k {new_key_str} -u {card_uid} -c {cmac_count} -o cmacs.json"
        else:
            # Generate CMACs with default key
            cmd = f"python3 scripts/hashed_cmacs.py -k 00000000000000000000000000000000 -u {card_uid} -c {cmac_count} -o cmacs.json"
        exit_code, stdout, stderr = run_command(cmd)
        if exit_code != 0:
            print(f"Error generating CMACs: {stderr}")
            return False
        print("Generated CMACs successfully")

        # Add --ic flag to dfx calls when in IC mode
        ic_flag = "--ic " if ic_mode else ""

        cmd = f"dfx canister call {ic_flag}{canister_name} add_protected_route '(\"{page}\")'"
        exit_code, stdout, stderr = run_command(cmd)
        if exit_code != 0:
            print(f"Error adding protected route: {stderr}")
            return False
        print("Added protected route successfully")

        # Pass the ic_mode flag to batch_cmacs.py
        ic_flag_param = "--ic" if ic_mode else ""
        cmd = f"python3 scripts/batch_cmacs.py cmacs.json {canister_name} {page} {ic_flag_param}"
        exit_code, stdout, stderr = run_command(cmd)
        if exit_code != 0:
            print(f"Error uploading CMACs: {stderr}")
            return False
        print("Uploaded CMACs successfully")

        # Invalidate cache
        # cmd = f'dfx canister call {ic_flag}{canister_name} invalidate_cache'
        # exit_code, stdout, stderr = run_command(cmd)
        # if exit_code != 0:
        #     print(f"Error invalidating cache: {stderr}")
        #     return False
        # print("Invalidated cache successfully")

        return True

    except Exception as e:
        print(f"An error occurred: {str(e)}")
        return False
    finally:
        ntp.ReaderClose()


##########################################################################


def main():
    parser = argparse.ArgumentParser(
        description="Program NFC card and set up protected route"
    )
    parser.add_argument("canister_id", help="The canister ID")
    parser.add_argument("page", help="The page to protect (e.g., page1.html)")
    parser.add_argument(
        "--random-key",
        action="store_true",
        help="Generate and use a random key instead of default",
    )
    parser.add_argument(
        "--params", help="Additional query parameters (e.g., param1=value1)"
    )
    parser.add_argument(
        "--ic",
        action="store_true",
        help="Use IC production mode (connects to ICP network instead of local replica)",
    )
    parser.add_argument(
        "--cmac-count",
        type=int,
        default=20000,
        help="Number of CMACs to generate (default: 20000)",
    )

    args = parser.parse_args()

    if setup_route_and_program(
        args.canister_id,
        args.page,
        args.params,
        args.random_key,
        args.ic,
        args.cmac_count,
    ):
        print("\nSetup completed successfully!")
    else:
        print("\nSetup failed!")


if __name__ == "__main__":
    main()
