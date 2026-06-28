import re

with open("modules/bar/Bar.qml", "r") as f:
    lines = f.readlines()

# We want to move `RowLayout {` down to just before `Repeater {`
# And remove it from line 22
out_lines = []
in_row_layout = False
for i, line in enumerate(lines):
    if line.strip() == "RowLayout {":
        in_row_layout = True
        continue
    if in_row_layout and "id: layout" in line:
        continue
    if in_row_layout and "anchors.fill: parent" in line:
        continue
    if in_row_layout and "spacing: Tokens.spacing.medium" in line:
        in_row_layout = False
        continue

    if "Repeater {" in line:
        out_lines.append("    RowLayout {\n")
        out_lines.append("        id: layout\n")
        out_lines.append("        anchors.fill: parent\n")
        out_lines.append("        spacing: Tokens.spacing.medium\n\n")

    if "component WrappedLoader: Loader {" in line:
        # Close RowLayout before component
        out_lines.append("    }\n\n")
    
    out_lines.append(line)

with open("modules/bar/Bar.qml", "w") as f:
    f.writelines(out_lines)

