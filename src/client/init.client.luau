-- Kinfield client entry point.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local State = require(script.State)
local App = require(script.UI.App)
local HUD = require(script.Controllers.HUD)
local Farming = require(script.Controllers.Farming)
local World = require(script.Controllers.World)
local Feedback = require(script.Controllers.Feedback)
local Animator = require(script.Controllers.Animator)

State.start()
local gui = App.build()

require(script.UI.Panels.FarmPanels)(App, Farming)
require(script.UI.Panels.ItemPanels)(App, Farming)
require(script.UI.Panels.AnimalPanels)(App)
require(script.UI.Panels.CraftPanels)(App)
require(script.UI.Panels.SocialPanels)(App)
require(script.UI.Panels.StorePanels)(App)

HUD.build(gui)
Farming.build(gui)
Feedback.build(gui)
World.start()
Animator.start()

-- start listening last so no push arrives before its handler exists
Net.startClient()
