-- LOCAL
local main = require(game.HDAdmin)
local Parser = {}



-- START
function Parser:init()
	-- This is called when the module is easy-loaded (currently easy-loaded from CommandService)
	-- You can use it for testing, e.g:
	local message = ";globalPaint(red) all"
	local batches = Parser.parseMessage(message)
	main.modules.TableUtil.print(batches, "Batches", true)
end


-- METHODS
function Parser.parseMessage(message)
	-- You are welcome to split this method into submethods to achieve
	-- the final parsed result (i.e. an array of parsed batches)
	-- The following examples below demonstrate how to reference data,
	-- such as role and settings values, with V3. To view a records default values,
	-- either load up 'Config' (under HDAdmin.Core.Config) the values
	-- within a services .generateRecord method
	
	-- Data grabber examples to help you with the parser:
	local CommandService = (main.isServer and main.services.CommandService) or main.controllers.CommandController
	local commandRecord = CommandService:getRecord("commandName")
	local commandRecords = CommandService:getAllRecords()
	local SettingService = (main.isServer and main.services.SettingService) or main.controllers.SettingController
	local clientSettings = SettingService:getRecord("Client")
	local prefixes = clientSettings.prefixes
	local collective = clientSettings.collective
	local spaceSeparator = clientSettings.spaceSeparator
	local Args = main.modules.Parser.Args
	local argsDictionary = Args.dictionary
	local Modifiers = main.modules.Parser.Modifiers
	local modifiersDictionary = Modifiers.dictionary
	local modifiersSortedArray = Modifiers.sortedArray
	local Qualifiers = main.modules.Parser.Qualifiers
	local qualifiersDictionary = Qualifiers.dictionary

	local batches = {test345 = true}
	return batches
end



return Parser