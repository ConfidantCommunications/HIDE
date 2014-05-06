package core;
import cm.Editor;
import CodeMirror;
import completion.Filter;
import completion.Hxml;
import completion.MetaTags;
import completion.SnippetsCompletion;
import haxe.ds.StringMap.StringMap;
import haxe.xml.Fast;
import js.Browser;
import js.html.DivElement;
import js.html.SpanElement;
import js.Node;
import openproject.OpenFL;
import parser.ClassParser;
import projectaccess.Project;
import projectaccess.ProjectAccess;
import tabmanager.TabManager;
/**
 * ...
 * @author AS3Boyan
 */

enum CompletionType
{
	REGULAR;
	FILELIST;
	CLASSLIST;
	HXML;
	METATAGS;
}
 
typedef CompletionItem = 
{
	@:optional
	var d:String;
	@:optional
	var t:String;
	var n:String;
}
 
class Completion
{
	static var list:Array<CompletionData>;
	static var editor:CodeMirror;
	static var word:EReg;
	static var range:Int;
	static var cur:Pos;
	static private var end:Int;
	static private var start:Int;
	static var WORD:EReg = ~/[A-Z]+$/i;
	static var RANGE = 500;
	public static var curWord:String;
	public static var completions:Array<CompletionItem> = [];
	static var completionType:CompletionType = REGULAR;
	static var backupDocValue:String;
	
	public static function registerHelper() 
	{
		Hxml.load();
		MetaTags.load();
		SnippetsCompletion.load();
		
		CodeMirror.registerHelper("hint", "haxe", getHints);
		CodeMirror.registerHelper("hint", "hxml", getHints);
		
		Editor.editor.on("startCompletion", function (cm:CodeMirror):Void 
		{
			if (completionType == FILELIST) 
			{
				backupDocValue = TabManager.getCurrentDocument().getValue();
			}
		}
		);
	}
	
	static function getHints(cm:CodeMirror, options)
	{		
		word = null;
		
		range = null;
		
		if (options != null && options.range != null)
		{
			range = options.range;
		}
		else if (RANGE != null)
		{
			range = RANGE;
		}
		
		getCurrentWord(cm, options);

		list = new Array();
		
		switch (completionType) 
		{
			case REGULAR:
				for (completion in completions) 
				{
					var completionItem:CompletionData = { text: completion.n };
					
					var functionData = FunctionParametersHelper.parseFunctionParams(completion);
					
					var info:String;
					
					completionItem.className = "CodeMirror-Tern-completion";
					
					if (functionData.parameters != null) 
					{
						info = completion.n + "(" + functionData.parameters.join(", ") + ")" + ":" + functionData.retType;
						completionItem.className += " CodeMirror-Tern-completion-fn";
					}
					else
					{
						info = completion.t;
						
						switch (info) 
						{
							case "Bool":
								completionItem.className += " CodeMirror-Tern-completion-bool";
							case "Float", "Int", "UInt":
								completionItem.className += " CodeMirror-Tern-completion-number";
							case "String":
								completionItem.className += " CodeMirror-Tern-completion-string";
							default:
								if (info.indexOf("Array") != -1) 
								{
									completionItem.className += " CodeMirror-Tern-completion-array";
								}
								else if(info.indexOf("Map") != -1 || info.indexOf("StringMap") != -1) 
								{
									completionItem.className += " CodeMirror-Tern-completion-map";
								}
								else 
								{
									completionItem.className += " CodeMirror-Tern-completion-object";
								}
						}
					}
					
					var infoSpan:SpanElement = Browser.document.createSpanElement();
					
					var infoTypeSpan:SpanElement = Browser.document.createSpanElement();
					infoTypeSpan.textContent = info;
					infoSpan.appendChild(infoTypeSpan);
					
					infoSpan.appendChild(Browser.document.createElement("br"));
					infoSpan.appendChild(Browser.document.createElement("br"));
					
					var infoDescriptionSpan:SpanElement = Browser.document.createSpanElement();
					infoDescriptionSpan.className = "completionDescription";
					infoDescriptionSpan.innerHTML = completion.d;
					infoSpan.appendChild(infoDescriptionSpan);
					
					completionItem.info = function (completionItem) 
					{
						return infoSpan;
					};
					
					list.push(completionItem);
				}

				if (curWord == null || curWord.length == 0)
				{
				    list = list.concat(SnippetsCompletion.getCompletion());
				}
			case METATAGS:
				list = MetaTags.getCompletion();
			case HXML:
				list = Hxml.getCompletion();
			case FILELIST:
				for (item in ClassParser.filesList) 
				{
					list.push( { text: item, displayText: item, hint: openFile} );
				}
			case CLASSLIST:
				for (item in ClassParser.topLevelClassList) 
				{
					list.push( { text: item} );
				}
				
				for (item in ClassParser.importsList) 
				{
					list.push( { text: item} );
				}
			default:
				
		}
		
		list = Filter.filter(list, curWord, completionType);
		
		switch (completionType) 
		{
			case FILELIST:
				for (item in list) 
				{
					item.text = "";
				}
			default:
				
		}
		
		var data:Dynamic = { list: list, from: { line:cur.line, ch:start }, to: { line:cur.line, ch:end } };
		CodeMirrorStatic.attachContextInfo(Editor.editor, data);
		return data;
	}
	
	static function openFile(cm:CodeMirror, data:Dynamic, completion:CompletionData)
	{		
		var path = completion.displayText;
		
		if (ProjectAccess.path != null) 
		{
			path = Node.path.resolve(ProjectAccess.path, path);
		}
		
        TabManager.getCurrentDocument().setValue(backupDocValue);
            
		TabManager.openFileInNewTab(path);
	}
	
	public static function getCurrentWord(cm:CodeMirror, ?options:Dynamic, ?pos:Pos):{word:String, from:CodeMirror.Pos, to:CodeMirror.Pos}
	{
		if (options != null && options.word != null)
		{
			word = options.word;
		}
		else if (WORD != null)
		{
			word = WORD;
		}
		
		if (pos != null) 
		{
			cur = pos;
		}
		
		var curLine:String = cm.getLine(cur.line);
		start = cur.ch;
		
		end = start;
		
		while (end < curLine.length && word.match(curLine.charAt(end))) ++end;
		while (start > 0 && word.match(curLine.charAt(start - 1))) --start;
		
		curWord = null;
		
		if (start != end) 
		{
			curWord = curLine.substring(start, end);
		}
		
		return {word:curWord, from: {line:cur.line, ch: start}, to: {line:cur.line, ch: end}};
	}
	
	public static function getCompletion(onComplete:Dynamic, ?_pos:Pos)
	{
		if (ProjectAccess.path != null) 
		{
			var projectArguments:Array<String> = [];
			//= ProjectAccess.currentProject.args.copy();
			
			var project = ProjectAccess.currentProject;
			
			switch (project.type)
			{
				case Project.HAXE:
					var pathToHxml:String = project.targetData[project.target].pathToHxml;
					projectArguments.push(pathToHxml);
					processArguments(projectArguments, onComplete, _pos);
				case Project.HXML:
					projectArguments.push(project.main);
					processArguments(projectArguments, onComplete, _pos);
				case Project.OPENFL:
					OpenFL.parseOpenFLDisplayParameters(ProjectAccess.path, project.openFLTarget, function (args:Array<String>):Void 
					{
						projectArguments = args;
						processArguments(projectArguments, onComplete, _pos);
					}
					);
				default:
					
			}
		}
	}
	
	static function processArguments(projectArguments:Array<String>, onComplete:Dynamic, ?_pos:Pos):Void 
	{
		projectArguments.push("--no-output");
		projectArguments.push("--display");
		
		var cm:CodeMirror = Editor.editor;
		cur = _pos;
		
		if (_pos == null) 
		{
			cur = cm.getCursor();
		}
		
		getCurrentWord(cm, null, cur);
		
		if (curWord != null) 
		{
			cur = {line: cur.line,  ch:start};
		}
		
		projectArguments.push(TabManager.getCurrentDocumentPath() + "@" + Std.string(cm.indexFromPos(cur)));
		
		Completion.completions = [];
		
		var params = ["--connect", "5000", "--cwd", HIDE.surroundWithQuotes(ProjectAccess.path)].concat(projectArguments);
		
		ProcessHelper.runProcess("haxe", params, null, function (stdout:String, stderr:String)
		{
			var xml:Xml = Xml.parse(stderr);
			
			var fast = new Fast(xml);
			
			if (fast.hasNode.list)
			{
				var list = fast.node.list;
				
				var completion:CompletionItem;
				
				if (list.hasNode.i)
				{
					for (item in list.nodes.i) 
					{
						if (item.has.n)
						{
							completion = {n: item.att.n};
														
							if (item.hasNode.d)
							{
								var str = StringTools.trim(item.node.d.innerHTML);
								str = StringTools.replace(str, "\t", "");
								str = StringTools.replace(str, "\n", "");
								str = StringTools.replace(str, "*", "");
								str = StringTools.replace(str, "&lt;", "<");
								str = StringTools.replace(str, "&gt;", ">");
								str = StringTools.trim(str);
								completion.d = str;
							}
							
							if (item.hasNode.t)
							{
								completion.t = item.node.t.innerData;
								//var type = item.node.t.innerData;
								//switch (type) 
								//{
									//case "Float", "Int":
										//completion.type = "number";
									//case "Bool":
										//completion.type = "bool";
									//case "String":
										//completion.type = "string";
									//default:
										//completion.type = "fn()";
								//}
							}
							//else 
							//{
								//completion.type = "fn()";
							//}
							
							completions.push(completion);
						}
					}
				}
			}
			
			onComplete();
		}, 
		function (code:Int, stdout:String, stderr:String)
		{
			trace(code);
			trace(stderr);
			
			onComplete();
		}
		);
	}
	
	static function isEditorVisible():Bool
	{
		var editor = cast(Browser.document.getElementById("editor"), DivElement);
		return editor.style.display != "none";
	}
	
	public static function showRegularCompletion():Void
	{
		if (isEditorVisible()) 
		{
			Editor.regenerateCompletionOnDot = true;
			WORD = ~/[A-Z]+$/i;
			completionType = REGULAR;
			CodeMirrorStatic.showHint(Editor.editor, getHints, { completeSingle: false } );
		}
	}
	
	public static function showMetaTagsCompletion():Void
	{
		if (isEditorVisible()) 
		{
			WORD = ~/[A-Z@:]+$/i;
			completionType = METATAGS;
			CodeMirrorStatic.showHint(Editor.editor, null, { closeCharacters: untyped __js__("/[\\s()\\[\\]{};>,]/") } );
		}
	}
	
	public static function showHxmlCompletion():Void
	{
		if (isEditorVisible()) 
		{
			WORD = ~/[A-Z- ]+$/i;
			completionType = HXML;
			CodeMirrorStatic.showHint(Editor.editor, null, { closeCharacters: untyped __js__("/[()\\[\\]{};:>,]/") } );
		}
	}
	
	public static function showFileList():Void
	{		
		if (isEditorVisible()) 
		{
			Editor.regenerateCompletionOnDot = false;
			WORD = ~/[A-Z\.]+$/i;
			completionType = FILELIST;
			CodeMirrorStatic.showHint(Editor.editor, getHints);
		}
	}
	
	public static function showClassList(?ignoreWhitespace:Bool = false):Void
	{
		if (isEditorVisible()) 
		{
			Editor.regenerateCompletionOnDot = false;
			WORD = ~/[A-Z\.]+$/i;
			completionType = CLASSLIST;
			
			var closeCharacters = untyped __js__("/[\\s()\\[\\]{};>,]/");
			
			if (ignoreWhitespace) 
			{
				closeCharacters = untyped __js__("/[()\\[\\]{};>,]/");
			}
			
			CodeMirrorStatic.showHint(Editor.editor, null, { closeCharacters: closeCharacters  } );
		}
	}

	public static function getCompletionType()
    {
        return completionType;
    }

}
