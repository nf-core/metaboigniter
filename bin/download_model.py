#!/usr/bin/env python


# Written by Payam Emami and Axel Walter and released under the MIT license.



import argparse
import requests
import os


def download_file(url, local_filename):
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        with open(local_filename, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)
    return local_filename


def download_from_zenodo(zenodo_id):
    api_endpoint = f"https://zenodo.org/api/records/{zenodo_id}"
    response = requests.get(api_endpoint).json()
    file_records = response.get("files", [])

    for file_record in file_records:
        download_url = file_record["links"]["self"]
        local_filename = os.path.join(os.getcwd(), file_record["key"])
        download_file(download_url, local_filename)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download files from Zenodo given a Zenodo ID.")
    parser.add_argument("--polarity", type=str, help="Zenodo ID from which to download the files.")

    args = parser.parse_args()

    zenodo_DOIs = {"positive": 7947603, "negative": 7944658}
    download_from_zenodo(zenodo_DOIs[args.polarity])
