import os
import sys

src = sys.argv[1]

with open(src, "r") as f:
  lines = f.readlines()

out_lines = []
for line in lines:
  out_lines.append(line)
  if "syntax =" in line:
    pkg = os.path.dirname(src.lstrip("./"))
    out_lines.append(f"option go_package = \"github.com/buildbuddy-io/tensorflow-proto/{pkg}\";")

with open(src, "w") as f:
  f.writelines(out_lines)

