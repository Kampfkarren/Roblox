local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ServerScriptService.Tests.TestEZ)

TestEZ.TestBootstrap:run(
	{ script.Parent },
	TestEZ.Reporters.TextReports
)
