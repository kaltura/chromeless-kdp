package com.kaltura.kdpfl.model.vo
{
	import flash.display.DisplayObjectContainer;
	
	/**
	 * Class ConfigVO holds parameters related to the general configuration of the KDP. 
	 * 
	 */	
	public class ConfigVO
	{
		/**
		 * Parameter holds the flashvars passed to the KDP.
		 */		
		public var flashvars:Object;

		/**
		 * A unique ID for the loaded instance of the KDP. 
		 */		
		public var sessionId : String;
		
		public var root : DisplayObjectContainer;
		
		public var pluginsMap : Object;
	}
}