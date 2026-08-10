--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local Versions = require(Shared.Core.Versions)

assert(RunService:IsClient(), "client bootstrap must run on client")

print(string.format("[UNRENDERED] client foundation online | protocol=%d", Versions.NetworkProtocol))
