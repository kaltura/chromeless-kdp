package com.kaltura.kdpfl.controller
{
	import com.adobe.serialization.json.JSON;
	import com.kaltura.kdpfl.model.ConfigProxy;
	import com.kaltura.kdpfl.model.MediaProxy;
	import com.kaltura.kdpfl.model.SequenceProxy;
	import com.kaltura.kdpfl.model.type.NotificationType;
	import com.kaltura.kdpfl.model.type.PluginStatus;
	import com.kaltura.kdpfl.model.type.StreamerType;
	import com.kaltura.kdpfl.plugin.KPluginEvent;
	import com.kaltura.kdpfl.plugin.Plugin;
	import com.kaltura.kdpfl.plugin.PluginManager;
	import com.kaltura.kdpfl.util.KTextParser;
	import com.kaltura.kdpfl.util.URLUtils;
	import com.kaltura.kdpfl.view.controls.KTrace;
	import com.kaltura.kdpfl.model.ExternalInterfaceProxy;
	
	import flash.events.AsyncErrorEvent;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.command.AsyncCommand;
	
	/**
	 * This class loads plugins from flashvars
	 */	
	public class LoadPluginsCommand extends AsyncCommand
	{
		
		private var _pluginsCounter:int;
		private var _config:ConfigProxy;
		
		/**
		 * Set the flashvars into the Config Proxy
		 * @param note
		 * 
		 */		
		override public function execute(note:INotification):void
		{
			_config = facade.retrieveProxy(ConfigProxy.NAME) as ConfigProxy;
			var flashvars:Object = _config.vo.flashvars;
	
			var mediaProxy:MediaProxy = facade.retrieveProxy(MediaProxy.NAME) as MediaProxy;
			//add akamaiHd plugin if streamerType is akamaiHd
			if (mediaProxy.vo.deliveryType == StreamerType.HDNETWORK || mediaProxy.vo.deliveryType == StreamerType.HDNETWORK_HDS)
				flashvars.akamaiHD = {plugin: "true", asyncInit: "true", loadingPolicy: "preInitialize"};
			
			_config.vo.pluginsMap = {};
			_pluginsCounter = 0;
			var hasPlugins:Boolean;
			
			for(var pluginName:String in flashvars)
			{
				var pluginParams:Object = flashvars[pluginName];
				if (pluginParams && (pluginParams is String) && (pluginParams as String).indexOf("{") == 0)
					pluginParams = JSON.decode( pluginParams as String);
				if (pluginParams && pluginParams.hasOwnProperty('plugin') && (pluginParams['plugin'] == 'true' || pluginParams['plugin'] == true))
				{
					hasPlugins = true;
					//see if we need to wait for this plugin to load (loadingPolicy == "wait")
					var loadingPolicy : String = pluginParams.hasOwnProperty('loadingPolicy') ? pluginParams['loadingPolicy'] : 'wait';
					var asyncInit : Boolean = (pluginParams.hasOwnProperty('asyncInit') && pluginParams['asyncInit'] == "true") ? true : false;
					var pluginDomain : String = flashvars.pluginDomain ? flashvars.pluginDomain : (facade['appFolder'] + 'plugins/');
					var pluginUrl : String = pluginParams.hasOwnProperty('path') ? pluginParams['path'] : pluginName + "Plugin.swf";
					if (!URLUtils.isHttpURL(pluginUrl) && (pluginUrl.charAt(0) == "/") )
					{
						//change to more reliable params
						pluginUrl = flashvars.httpProtocol + flashvars.cdnHost + pluginUrl;
					}
					if(!URLUtils.isHttpURL(pluginUrl))
						pluginUrl = pluginDomain + pluginUrl;
					
					var uiComponent:Plugin = PluginManager.getInstance().loadPlugin(pluginUrl, pluginName, loadingPolicy , asyncInit, flashvars.fileSystemMode == true);
					if (loadingPolicy!="onDemand")
						_pluginsCounter++;
					
					_config.vo.pluginsMap[pluginName] = PluginStatus.NOT_READY;
					// we wait for ready for onDemand plugins as well in order to set their data and
					// initialize the plugin.
					// this event listener MUST HAVE a higher priority than the one set by the code
					// actually loading the plugin in order for the later to receive an initialized plugin 
					uiComponent.addEventListener( Event.COMPLETE , onPluginReady, false, int.MAX_VALUE);
					uiComponent.addEventListener( IOErrorEvent.IO_ERROR , onPluginError );
					uiComponent.addEventListener( SecurityErrorEvent.SECURITY_ERROR , onPluginError );
					uiComponent.addEventListener( ErrorEvent.ERROR , onPluginError );
					uiComponent.addEventListener( AsyncErrorEvent.ASYNC_ERROR , onPluginError );
					_config.vo.pluginsMap[pluginName] = PluginStatus.NOT_READY;
					facade['bindObject']['Plugin_' + pluginName] = uiComponent;
					//save plugin xml data, it will be overriden once the plugin is loaded.
					facade['bindObject'][pluginName] = pluginParams;
				}
			}
			
			if (!hasPlugins)
				commandComplete();
		}
		
		private function onAsyncResponse (event:KPluginEvent) : void {
			_pluginsCounter--;
			checkAllPluginsLoaded();
		}
		
		
		/**
		 * Handler for the PLUGIN_READY event fired by the PluginManager class, after the plugin was loaded and its properties successfully set.
		 * This function calls the plugins <code>initializePlugin</code> function. 
		 * @param event event received from the PluginManager.
		 * 
		 */		
		private function onPluginReady( event : Event ) : void
		{
			var plugin : Plugin = ( event.target as Plugin );
			removePluginListeners(plugin);
			_config.vo.pluginsMap[plugin.pluginName] = PluginStatus.READY;
			var attributesObj : Object = facade['bindObject'][plugin.pluginName];

			
			if(attributesObj.hasOwnProperty("preSequence"))
				(facade.retrieveProxy( SequenceProxy.NAME ) as SequenceProxy).vo.preSequenceCount +=1;
			
			if(attributesObj.hasOwnProperty("postSequence"))
				(facade.retrieveProxy( SequenceProxy.NAME ) as SequenceProxy).vo.postSequenceCount +=1;		
			
			for (var attr:String in attributesObj)
			{
				var val:String = attributesObj[attr];
				try
				{
					if ( plugin.content[attr] is Boolean)
					{
						plugin.content[attr]  = val == "true" || false;
					} else {
						plugin.content[attr] = val;
					}
					
					//KTextParser.bind(plugin.content, attr , facade['bindObject'], val);
				}
				catch(e:Error){
					if(_config.vo.flashvars.debugMode)
						KTrace.getInstance().log("could not push",attr,"=",val,"to",plugin);
					//trace("could not push",attrName,"=",attrValue,"to",comp);
				}
			}
			
			facade['bindObject'][plugin.pluginName] = plugin;
			if (plugin.asyncInit) { //increase loading qeue - wait until async init is complete
				plugin.content.addEventListener(KPluginEvent.KPLUGIN_INIT_COMPLETE, onAsyncResponse);
				plugin.content.addEventListener(KPluginEvent.KPLUGIN_INIT_FAILED, onAsyncResponse );
				_pluginsCounter ++;
			}
			plugin.content.initializePlugin( facade );	
			
			sendNotification(NotificationType.SINGLE_PLUGIN_LOADED, plugin.name);
			_pluginsCounter--;
			checkAllPluginsLoaded();
			
		}
		
		private function onPluginError( event: Event) : void 
		{
			var plugin : Plugin = ( event.target as Plugin );
			removePluginListeners(plugin);
			_config.vo.pluginsMap[plugin.name] = PluginStatus.LOAD_ERROR;	
			sendNotification(NotificationType.SINGLE_PLUGIN_FAILED_TO_LOAD, plugin.name);
			_pluginsCounter--;
			checkAllPluginsLoaded();
			
		}
		
		
		private function removePluginListeners(plugin:Plugin):void {
			plugin.removeEventListener( Event.COMPLETE , onPluginReady);
			plugin.removeEventListener( IOErrorEvent.IO_ERROR , onPluginError );
			plugin.removeEventListener( SecurityErrorEvent.SECURITY_ERROR , onPluginError );
			plugin.removeEventListener( ErrorEvent.ERROR , onPluginError );
			plugin.removeEventListener( AsyncErrorEvent.ASYNC_ERROR , onPluginError );
		}
		
		
		/**
		 * All plugins loaded- send notification 
		 * @param event
		 * 
		 */		 
		private function checkAllPluginsLoaded () : void {
			if (_pluginsCounter==0) {
				sendNotification(NotificationType.PLUGINS_READY, _config.vo.pluginsMap);
				commandComplete();	
			}
		}
		
		override protected function commandComplete():void {
			var extProxy:ExternalInterfaceProxy = facade.retrieveProxy(ExternalInterfaceProxy.NAME) as ExternalInterfaceProxy;
			extProxy.vo.enabled = true;
			extProxy.registerKDPCallbacks();
			//dispacth layout ready
			sendNotification(NotificationType.LAYOUT_READY);
			super.commandComplete();
		}
		
	}
}