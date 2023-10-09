#!/usr/bin/env python
import argparse
from os.path import join
from ms2query.create_new_library.train_models import clean_and_train_models

parser = argparse.ArgumentParser()
parser.add_argument("--input", help="input mgf library file")
parser.add_argument("--output", help="output dir")
parser.add_argument("--polarity", choices=["positive", "negative"], help="polarity")
args = parser.parse_args()
clean_and_train_models(spectrum_file=args.input, ion_mode=args.polarity, output_folder=args.output)
