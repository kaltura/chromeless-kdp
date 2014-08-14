package com.kaltura.kdpfl.controller
{
	import com.kaltura.kdpfl.model.SequenceProxy;
	
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.command.SimpleCommand;
	
	public class MidSequenceEndCommand extends SimpleCommand
	{
		public function MidSequenceEndCommand()
		{
			super();
		}
		
		override public function execute(notification:INotification):void
		{
			var sequenceProxy : SequenceProxy = facade.retrieveProxy( SequenceProxy.NAME ) as SequenceProxy;
			sequenceProxy.vo.midrollArr = new Array();
			sequenceProxy.vo.midCurrentIndex = -1;
			sequenceProxy.vo.isInSequence = false;
		}
	}
}