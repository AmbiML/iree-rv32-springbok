#!/usr/bin/env python3
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Generate ML model inputs from images."""
import argparse
import os
import struct
import urllib.request

import numpy as np
from PIL import Image


parser = argparse.ArgumentParser(
    description='Generate inputs for ML models.')
parser.add_argument('--i', dest='input_name',
                    help='Model input image name', required=True)
parser.add_argument('--o', dest='output_file',
                    help='Output binary name', required=True)
parser.add_argument('--s', dest='input_shape',
                    help='Model input shape (example: "1, 224, 224, 3")', required=True)
parser.add_argument('--q', dest='is_quant', action='store_true',
                    help='Indicate it is quant model (default: False)')
parser.add_argument('--r', dest='float_input_range', default="-1.0, 1.0",
                    help='Float model input range (default: "-1.0, 1.0")')
args = parser.parse_args()


def write_binary_file(file_path, input, is_quant):
    with open(file_path, "wb+") as file:
        for d in input:
            if is_quant:
                file.write(struct.pack("<B", d))
            else:
                file.write(struct.pack("<f", d))


def gen_mlmodel_input(input_name, output_file, input_shape, is_quant):
    if not os.path.exists(input_name):
        raise RuntimeError("Input file %s doesn't exist" % {input_name})
    if len(input_shape) < 3:
        raise ValueError("Input shape < 3 dimensions")
    input_ext = os.path.splitext(input_name)[1]
    if (not input_ext) or (input_ext == '.bin'):
        with open(input_name, mode='rb') as f:
            input = np.fromfile(f, dtype=np.uint8 if is_quant else np.float32).reshape(
                np.prod(input_shape))
    else:
        resized_img = Image.open(input_name).resize(
            (input_shape[2], input_shape[1]))
        input = np.array(resized_img).reshape(np.prod(input_shape))
        if not is_quant:
            low = np.min(float_input_range)
            high = np.max(float_input_range)
            input = (high - low) * input / 255.0 + low
    write_binary_file(output_file, input, is_quant)


if __name__ == '__main__':
    # convert input shape to a list
    input_shape = [int(x) for x in args.input_shape.split(',')]
    float_input_range = [float(x) for x in args.float_input_range.split(',')]
    gen_mlmodel_input(args.input_name, args.output_file,
                      input_shape, args.is_quant)
