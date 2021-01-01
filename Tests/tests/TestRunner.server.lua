local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ServerScriptService.Tests.TestEZ)

TestEZ.TestBootstrap:run(
	{ ServerScriptService.Tests },
	TestEZ.Reporters.TextReports
)
