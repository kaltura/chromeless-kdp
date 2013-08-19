package com.kaltura.kdpfl.controller
{
	import org.puremvc.as3.patterns.command.AsyncMacroCommand;

	/**
	 * This class defines the sequence of KDP initialization.  
	 */	
	public class InitMacroCommand extends AsyncMacroCommand
	{
			
		override protected function initializeAsyncMacroCommand():void
		{
			// save all flash vars
			addSubCommand( SaveFVCommand ); 	
			
			//load plugins
			addSubCommand ( LoadPluginsCommand );
		}
	}
}