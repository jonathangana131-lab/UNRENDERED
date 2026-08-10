from pathlib import Path

path = Path("src/shared/Objects/ObjectGenome.luau")
text = path.read_text()
old = '''\tif mechanism.kind == "hinge" or mechanism.kind == "tilt" then
\t\tassert(
\t\t\tisFinite(mechanism.minDegrees)
\t\t\t\tand isFinite(mechanism.maxDegrees)
\t\t\t\tand mechanism.minDegrees < mechanism.maxDegrees
\t\t\t\tand mechanism.minDegrees <= 0
\t\t\t\tand mechanism.maxDegrees >= 0,
\t\t\t"angular mechanism limits must include the authored zero/reference pose"
\t\t)
\t\treturn {
\t\t\tkind = mechanism.kind,
\t\t\tdegrees = mechanism.minDegrees + position * (mechanism.maxDegrees - mechanism.minDegrees),
\t\t}
\telseif mechanism.kind == "slide" then
'''
new = '''\tif mechanism.kind == "hinge" then
\t\tassert(
\t\t\tisFinite(mechanism.minDegrees)
\t\t\t\tand isFinite(mechanism.maxDegrees)
\t\t\t\tand mechanism.minDegrees < mechanism.maxDegrees
\t\t\t\tand mechanism.minDegrees <= 0
\t\t\t\tand mechanism.maxDegrees >= 0,
\t\t\t"angular mechanism limits must include the authored zero/reference pose"
\t\t)
\t\treturn {
\t\t\tkind = "hinge",
\t\t\tdegrees = mechanism.minDegrees + position * (mechanism.maxDegrees - mechanism.minDegrees),
\t\t}
\telseif mechanism.kind == "tilt" then
\t\tassert(
\t\t\tisFinite(mechanism.minDegrees)
\t\t\t\tand isFinite(mechanism.maxDegrees)
\t\t\t\tand mechanism.minDegrees < mechanism.maxDegrees
\t\t\t\tand mechanism.minDegrees <= 0
\t\t\t\tand mechanism.maxDegrees >= 0,
\t\t\t"angular mechanism limits must include the authored zero/reference pose"
\t\t)
\t\treturn {
\t\t\tkind = "tilt",
\t\t\tdegrees = mechanism.minDegrees + position * (mechanism.maxDegrees - mechanism.minDegrees),
\t\t}
\telseif mechanism.kind == "slide" then
'''
if text.count(old) != 1:
    raise SystemExit(f"decoder marker count was {text.count(old)}")
path.write_text(text.replace(old, new, 1))
