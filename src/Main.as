package
{
	import flash.desktop.Icon;
	import flash.desktop.NativeApplication;
	import flash.desktop.SystemTrayIcon;
	import flash.display.Bitmap;
	import flash.display.NativeMenu;
	import flash.display.NativeMenuItem;
	import flash.display.NativeWindow;
	import flash.display.NativeWindowInitOptions;
	import flash.display.NativeWindowType;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.filters.BitmapFilterType;
	import flash.filters.DropShadowFilter;
	import flash.filters.GlowFilter;
	import flash.filters.GradientGlowFilter;
	import flash.system.Capabilities;
	import flash.text.AntiAliasType;
	import flash.text.Font;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.utils.Timer;
	
	/**
	 * ...
	 * @author Gamba
	 */
	public class Main extends Sprite
	{
		[Embed(source="YaHei.Consolas.1.12.ttf",embedAsCFF="false",fontName="bb_font")]
		private const EMBED_FONT:Class;
		private const BB_FONT:Font = new EMBED_FONT() as Font;
		private const DEFAULT_TEXT_FORMAT:TextFormat = new TextFormat(BB_FONT.fontName, 15, 0x222222, true, null, null, null, null, TextFormatAlign.JUSTIFY, 10, 10, 20, 2);
		
		[Embed(source = "ico.png")]
		private const ICON:Class;
		private const APP_CION:Bitmap = new ICON() as Bitmap;
		
		private const MAIN_CONTAINER_WIDTH:Number = 240;
		private const DRAG_BAR_RADIUS:Number = 6;
		private const DATA_PATH:String = "workListData.wld";
		private const PADDING:Number = 8;
		
		private var _isHide:Boolean = false;
		private var _mainContainer:Sprite;
		private var _menu:Sprite;
		private var _fileStream:FileStream;
		private var _mainWidow:NativeWindow;
		
		public function Main():void
		{
			//app configuration
			var iconMenu:NativeMenu = new NativeMenu();
			var exitCommand:NativeMenuItem = iconMenu.addItem(new NativeMenuItem("EXIT"));
			exitCommand.addEventListener(Event.SELECT,onExit);
			NativeApplication.nativeApplication.autoExit = true;
			if (NativeApplication.supportsSystemTrayIcon)
			{
				var systray:SystemTrayIcon = NativeApplication.nativeApplication.icon as SystemTrayIcon;
				systray.tooltip = "Gim Worklist Manager | GimStudio® Copyright";
				systray.menu = iconMenu;
				NativeApplication.nativeApplication.icon.bitmaps = [APP_CION.bitmapData];
			}
			
			//window configuration
			var initOptions:NativeWindowInitOptions = new NativeWindowInitOptions();
			initOptions.type = NativeWindowType.UTILITY;
			initOptions.minimizable = false;
			initOptions.systemChrome = "none";
			initOptions.transparent = true;
			_mainWidow = new NativeWindow(initOptions);
			_mainWidow.activate();
			_mainWidow.alwaysInFront = false;
			_mainWidow.x = 0;
			_mainWidow.y = 0;
			
			//stage configuration
			_mainWidow.stage.align = StageAlign.TOP_LEFT;
			_mainWidow.stage.scaleMode = StageScaleMode.NO_SCALE;
			_mainWidow.stage.stageWidth = Capabilities.screenResolutionX;
			_mainWidow.stage.stageHeight = Capabilities.screenResolutionY;
			
			//main container
			_mainContainer = new Sprite();
			_mainWidow.stage.addChild(_mainContainer);
			
			_mainContainer.x = _mainWidow.stage.stageWidth - MAIN_CONTAINER_WIDTH;
			_mainContainer.graphics.beginFill(0xffff99, 0.9);
			_mainContainer.graphics.drawRect(0, 0, MAIN_CONTAINER_WIDTH, 600);
			_mainContainer.graphics.endFill();
			_mainContainer.filters = [new DropShadowFilter(0, 0, 0x222222, 0.8, 4, 4)];
			
			//textfield
			var textField:TextField = new TextField();
			_mainContainer.addChild(textField);
			
			textField.width = _mainContainer.width;
			textField.height = _mainContainer.height - PADDING - PADDING;
			textField.y = PADDING;
			textField.defaultTextFormat = DEFAULT_TEXT_FORMAT;
			textField.type = TextFieldType.INPUT;
			textField.cacheAsBitmap = true;
			textField.embedFonts = true;
			textField.antiAliasType = AntiAliasType.ADVANCED;
			textField.wordWrap = true;
			textField.multiline = true;
			
			//menuPoint
			var menuPoint:Sprite = new Sprite();
			_mainWidow.stage.addChild(menuPoint);
			
			menuPoint.buttonMode = true;
			menuPoint.useHandCursor = true;
			menuPoint.x = _mainWidow.stage.stageWidth;
			menuPoint.graphics.beginFill(0xff0033, 0.9);
			menuPoint.graphics.drawCircle(0, 0, DRAG_BAR_RADIUS);
			menuPoint.graphics.endFill();
			menuPoint.filters = [new GlowFilter(0xffffff, 0.6), new DropShadowFilter(0,0,0,0.8)];
			
			//menu
			_menu = new Sprite();
			_mainWidow.stage.addChild(_menu);
			
			_menu.x = _mainWidow.stage.stageWidth - 100;
			_menu.graphics.beginFill(0xffffff, 0.9);
			_menu.graphics.drawRect(0, 0, 100, 100);
			_menu.graphics.endFill();
			_menu.filters = [new DropShadowFilter(0, 0, 0x222222, 0.8, 4, 4)];
			_menu.visible = false;
			
			//exit button
			var exitButton:TextField = new TextField();
			_menu.addChild(exitButton);
			exitButton.text = "EXIT";
			exitButton.border = true;
			exitButton.height = 18;
			exitButton.width = _menu.width;
			exitButton.selectable = false;
			
			//fileStream
			var file:File = new File(File.applicationDirectory.resolvePath(DATA_PATH).nativePath);
			_fileStream = new FileStream();
			_fileStream.open(file, FileMode.UPDATE);
			textField.text = _fileStream.readUTFBytes(_fileStream.bytesAvailable);
			
			//event listeners
			textField.addEventListener(Event.CHANGE, onTextFieldChange);
			menuPoint.addEventListener(MouseEvent.CLICK, onMenuPointClick);
			menuPoint.addEventListener(MouseEvent.RIGHT_CLICK, onMenuPointRightClick);
			_mainWidow.stage.addEventListener(MouseEvent.CLICK, onClick);
			exitButton.addEventListener(MouseEvent.CLICK, onExit);
		}
		
		/*
		 * textField change handler
		 * */
		private function onTextFieldChange(e:Event):void
		{
			var string:String = (e.currentTarget as TextField).text;
			_fileStream.position = 0;
			_fileStream.truncate();
			_fileStream.writeUTFBytes(string);
		}
		
		/*
		 * menu point click handler
		 * */
		private function onMenuPointClick(e:MouseEvent):void
		{
			_isHide = !_isHide;
			
			TweenLite.killTweensOf(_mainContainer);
			TweenLite.to(_mainContainer, 0.5, {scaleX: (_isHide ? 0 : 1), scaleY: (_isHide ? 0 : 1), x: _mainWidow.stage.stageWidth - (_isHide ? 0 : MAIN_CONTAINER_WIDTH)});
		}
		
		/*
		 * menu point right click handler
		 * */
		private function onMenuPointRightClick(e:MouseEvent):void
		{
			_menu.visible = true;
		}
		
		/*
		 * main click handler
		 * */
		private function onClick(e:MouseEvent):void
		{
			_menu.visible = false;
		}
		
		/*
		 * application exit handler
		 * */
		private function onExit(e:Event):void
		{
			NativeApplication.nativeApplication.icon.bitmaps = [];
			NativeApplication.nativeApplication.exit();
		}
	
	}

}