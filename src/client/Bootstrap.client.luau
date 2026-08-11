--!strict

local RunService = game:GetService("RunService")

assert(RunService:IsClient(), "client bootstrap must run on client")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local Versions = require(Shared.Core.Versions)

print(string.format("[UNRENDERED] client foundation online | protocol=%d", Versions.NetworkProtocol))
