package ;
import core.TabsManager;
import jQuery.JQuery;
import js.Browser;
import js.html.AnchorElement;
import js.html.LIElement;
import js.html.MouseEvent;
import js.html.UListElement;

/**
 * ...
 * @author ...
 */
class FileTree
{

	public function new() 
	{
		
	}
	
	public static function init():Void
	{
		var tree:UListElement = cast(Browser.document.getElementById("tree"), UListElement);
		
		var rootTreeElement:LIElement = createDirectoryElement("HIDE");		
		
		tree.appendChild(rootTreeElement);
		
		readDir("../", rootTreeElement);
	}
	
	private static function createDirectoryElement(text:String):LIElement
	{
		var directoryElement:LIElement = Browser.document.createLIElement();
		
		var a:AnchorElement = Browser.document.createAnchorElement();
		a.className = "tree-toggler nav-header";
		a.href = "#";
		
		var span = Browser.document.createSpanElement();
		span.className = "glyphicon glyphicon-folder-open";
		a.appendChild(span);
		
		span = Browser.document.createSpanElement();
		span.textContent = text;
		span.style.marginLeft = "5px";
		a.appendChild(span);
		
		//var textNode = Browser.document.createTextNode(text);
		//a.appendChild(textNode);
		
		a.onclick = function (e:MouseEvent):Void
		{
			new JQuery(directoryElement).children('ul.tree').toggle(300);
			Main.resize();
		};
		
		//var label:LabelElement = Browser.document.createLabelElement();
		//label.className = "tree-toggler nav-header";
		//label.textContent = text;
		
		directoryElement.appendChild(a);
		
		var ul:UListElement = Browser.document.createUListElement();
		ul.className = "nav nav-list tree";
		
		directoryElement.appendChild(ul);
		
		return directoryElement;
	}
	
	private static function readDir(path:String, topElement:LIElement):Void
	{				
		Utils.fs.readdir(path, function (error:js.Node.NodeErr, files:Array<String>):Void
		{			
			var foldersCount:Int = 0;
			
			for (file in files)
			{
				var filePath:String = Utils.path.join(path, file);
				
				Utils.fs.stat(filePath, function (error:js.Node.NodeErr, stat:js.Node.NodeStat)
				{					
					if (stat.isFile())
					{
						var li:LIElement = Browser.document.createLIElement();
						
						var a:AnchorElement = Browser.document.createAnchorElement();
						a.href = "#";
						a.textContent = file;
						a.title = filePath;
						a.onclick = function (e):Void
						{
							TabsManager.openFileInNewTab(filePath);
						};
						
						if (StringTools.endsWith(file, ".hx"))
						{
							a.style.fontWeight = "bold";
						}
						else if (StringTools.endsWith(file, ".hxml"))
						{
							a.style.fontWeight = "bold";
							a.style.color = "gray";
						}
						else
						{
							a.style.color = "gray";
						}
						
						li.appendChild(a);
						
						var ul:UListElement = cast(topElement.getElementsByTagName("ul")[0], UListElement);
						ul.appendChild(li);
					}
					else
					{
						if (!StringTools.startsWith(file, "."))
						{
							var ul:UListElement = cast(topElement.getElementsByTagName("ul")[0], UListElement);
							
							var directoryElement:LIElement = createDirectoryElement(file);
							
							//Lazy loading
							directoryElement.onclick = function (e):Void
							{
								if (directoryElement.getElementsByTagName("ul")[0].childNodes.length == 0)
								{
									readDir(filePath, directoryElement);
									e.stopPropagation();
									e.preventDefault();
									directoryElement.onclick = null;
								}
							}
							
							ul.appendChild(directoryElement);
							ul.insertBefore(directoryElement, ul.childNodes[foldersCount]);
							foldersCount++;
						}
					}
				}
				);
			}
			
			new JQuery(topElement).children('ul.tree').show(300);
		}
		);
	}
	
}