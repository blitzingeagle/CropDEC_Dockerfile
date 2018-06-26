import os
from glob import glob
from argparse import ArgumentParser

parser = ArgumentParser("CropDEC")
parser.add_argument("-t", "--target", type=str, metavar="TARGET", help="Target item to crop.")
parser.add_argument("-i", "--input", type=str, metavar="INPUT", help="Input video.")
parser.add_argument("-f", "--frames", type=str, metavar="FRAMES", help="Location of frames.")
parser.add_argument("-o", "--output", type=str, metavar="OUTPUT", help="Location of output.")

args = parser.parse_args()

cmds = [
    "python3 CropYOLO/main.py -t {0} -i {1} -f {2} -o {3}".format(args.target, args.input, args.frames, args.output),
    "cd ImageDEC/src && python main.py -t {0} -p {1} -loc {2}".format(args.target, os.path.join(args.output, os.path.splitext(os.path.basename(args.input$
]

for cmd in cmds:
    print(cmd)
    os.system(cmd)

