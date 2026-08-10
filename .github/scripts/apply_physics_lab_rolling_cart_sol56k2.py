from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one marker, found {count}")
    p.write_text(text.replace(old, new, 1))


replace_once(
    "src/shared/Physics/PhysicsLabRecipe.luau",
    '''\t| "dynamic-box"
\t| "static-wedge"
''',
    '''\t| "dynamic-box"
\t| "rolling-cart-proxy"
\t| "static-wedge"
''',
)

replace_once(
    "src/shared/Physics/PhysicsLabRecipe.luau",
    '''\t\tassert(WorldEntity.isId(element.entity.id), `invalid WorldEntityId for {element.key}`)
\t\tassert(not seenIds[element.entity.id], `duplicate Physics Lab WorldEntityId: {element.entity.id}`)
''',
    '''\t\tassert(WorldEntity.isId(element.entity.id), `invalid WorldEntityId for {element.key}`)
\t\tassert(element.entity.id == worldEntityId(element.key), `{element.key} WorldEntityId derivation mismatch`)
\t\tassert(not seenIds[element.entity.id], `duplicate Physics Lab WorldEntityId: {element.entity.id}`)
''',
)

replace_once(
    "src/shared/Physics/PhysicsLabRecipe.luau",
    '''\t\t"dynamic-box",
\t\t"F3"
\t)

\tfor stepIndex = 1, 4 do
''',
    '''\t\t"rolling-cart-proxy",
\t\t"F3"
\t)

\tfor stepIndex = 1, 4 do
''',
)

realizer_marker = '''local function realizeWedge(element: LabElement, parent: Instance): ()
'''
rolling_cart = '''local function realizeRollingCart(element: LabElement, parent: Instance): ()
\tlocal model = newEntityModel(element, parent)
\tlocal size = vector3(element.sizeStuds)
\tlocal bodyCFrame = cframeFor(element)
\tlocal chassisSize = Vector3.new(size.X, math.max(0.45, size.Y * 0.42), size.Z)
\tlocal chassis = newPart("Chassis", chassisSize, bodyCFrame, false, element.material, model)
\tapplyEntityDiagnostics(chassis, element)
\tchassis:SetNetworkOwner(nil)

\tlocal wheelDiameter = math.max(0.65, math.min(size.X, size.Z) * 0.28)
\tlocal wheelWidth = math.max(0.32, wheelDiameter * 0.42)
\tlocal halfX = math.max(0.1, size.X * 0.5 - wheelWidth * 0.55)
\tlocal halfZ = math.max(0.1, size.Z * 0.5 - wheelDiameter * 0.55)
\tlocal wheelY = -chassisSize.Y * 0.5 + wheelDiameter * 0.15
\n\tlocal wheelOffsets = {
\t\tVector3.new(-halfX, wheelY, -halfZ),
\t\tVector3.new(halfX, wheelY, -halfZ),
\t\tVector3.new(-halfX, wheelY, halfZ),
\t\tVector3.new(halfX, wheelY, halfZ),
\t}
\tfor index, offset in ipairs(wheelOffsets) do
\t\tlocal wheelCFrame = bodyCFrame * CFrame.new(offset)
\t\tlocal wheel = newPart(
\t\t\t`Wheel{index}`,
\t\t\tVector3.new(wheelWidth, wheelDiameter, wheelDiameter),
\t\t\twheelCFrame,
\t\t\tfalse,
\t\t\telement.material,
\t\t\tmodel
\t\t)
\t\twheel.Shape = Enum.PartType.Cylinder
\t\twheel:SetNetworkOwner(nil)

\t\tlocal chassisAttachment = Instance.new("Attachment")
\t\tchassisAttachment.Name = `WheelMount{index}`
\t\tchassisAttachment.Position = offset
\t\tchassisAttachment.Axis = Vector3.new(1, 0, 0)
\t\tchassisAttachment.Parent = chassis

\t\tlocal wheelAttachment = Instance.new("Attachment")
\t\twheelAttachment.Name = `WheelAxle{index}`
\t\twheelAttachment.Axis = Vector3.new(1, 0, 0)
\t\twheelAttachment.Parent = wheel

\t\tlocal hinge = Instance.new("HingeConstraint")
\t\thinge.Name = `WheelHinge{index}`
\t\thinge.Attachment0 = chassisAttachment
\t\thinge.Attachment1 = wheelAttachment
\t\thinge.Parent = model
\tend

\tmodel.PrimaryPart = chassis
\taddStudioDiagnostic(chassis, element)
end

'''
replace_once(
    "src/server/PhysicsLab/PhysicsLabRealizer.luau",
    realizer_marker,
    rolling_cart + realizer_marker,
)

replace_once(
    "src/server/PhysicsLab/PhysicsLabRealizer.luau",
    '''\telseif element.representationKind == "static-wedge" then
''',
    '''\telseif element.representationKind == "rolling-cart-proxy" then
\t\trealizeRollingCart(element, parent)
\telseif element.representationKind == "static-wedge" then
''',
)

replace_once(
    "tests/physics_lab_recipe.luau",
    '''\tlocal hasHingedDoor = false
\tlocal hasDrawerProxy = false
\tlocal stairCount = 0
''',
    '''\tlocal hasHingedDoor = false
\tlocal hasDrawerProxy = false
\tlocal hasRollingCart = false
\tlocal stairCount = 0
''',
)
replace_once(
    "tests/physics_lab_recipe.luau",
    '''\t\telseif element.role == "cabinet" and element.representationKind == "sliding-drawer-proxy" then
\t\t\thasDrawerProxy = true
\t\telseif element.role == "stairs" then
''',
    '''\t\telseif element.role == "cabinet" and element.representationKind == "sliding-drawer-proxy" then
\t\t\thasDrawerProxy = true
\t\telseif element.role == "cart" and element.representationKind == "rolling-cart-proxy" then
\t\t\thasRollingCart = true
\t\telseif element.role == "stairs" then
''',
)
replace_once(
    "tests/physics_lab_recipe.luau",
    '''\texpect("lab includes a drawer mechanism representation contract", hasDrawerProxy)
\texpect("lab stairs are actual stepped geometry", stairCount >= 4)
''',
    '''\texpect("lab includes a drawer mechanism representation contract", hasDrawerProxy)
\texpect("lab includes a four-wheel rolling-cart representation contract", hasRollingCart)
\texpect("lab stairs are actual stepped geometry", stairCount >= 4)
''',
)

replace_once(
    "Docs/PHYSICS_LAB.md",
    "- a dynamic rolling-cart mass proxy;\n",
    "- a four-wheel rolling-cart proxy whose chassis and wheels are server-owned rigidbodies connected by hinge constraints;\n",
)
replace_once(
    "Docs/PHYSICS_LAB.md",
    "- push the unanchored chair/table/cart proxies and confirm they are actual physics bodies;\n",
    "- push the unanchored chair/table proxies and roll the cart to confirm the cart wheels remain axle-constrained to the server-owned chassis;\n",
)
