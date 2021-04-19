//CommandManager for JavaScript by Alexander Brevig Modified by EL SoftWare, Inc.  Copyright 2015(c) EL SoftWare, Inc.
//ESWRAnnotate Originated from http://www.codeproject.com/Articles/801111/Html-Image-Markup. Rewritten By EL SoftWare, Inc.  Copyright 2015(c) EL SoftWare, Inc.

window.ESWRAnnotationInDialog = 0;
window.ESWRAnnotationClickCounter = 0;

var CommandManager = (function () {
	function CommandManager() {}

	CommandManager.executed = [];
	CommandManager.unexecuted = [];
  
	CommandManager.execute = function execute(par_cmd) {
		par_cmd.execute();
		CommandManager.executed.push(par_cmd);
	};
  
	CommandManager.AddAsExecuted = function AddAsExecuted(par_cmd) {
		CommandManager.executed.push(par_cmd);
	};
  
	CommandManager.undo = function undo() {
		if (CommandManager.executed.length > 0) {
			window.ESWRAnnotationCMD = CommandManager.executed.pop();
			if (window.ESWRAnnotationCMD !== undefined){
				if (window.ESWRAnnotationCMD.unexecute !== undefined){
					window.ESWRAnnotationCMD.project.activate();
					window.ESWRAnnotationCMD.unexecute();
				}
				CommandManager.unexecuted.push(window.ESWRAnnotationCMD);
			}
		}
	};
  
	CommandManager.redo = function redo() {
		if (CommandManager.unexecuted.length > 0) {
			window.ESWRAnnotationCMD = CommandManager.unexecuted.pop();
    
			//if (window.ESWRAnnotationCMD === undefined){
			//  window.ESWRAnnotationCMD = CommandManager.executed.pop();
			// CommandManager.executed.push(window.ESWRAnnotationCMD); 
			//  CommandManager.executed.push(window.ESWRAnnotationCMD); 
			//}
			
			if (window.ESWRAnnotationCMD !== undefined){
				window.ESWRAnnotationCMD.project.activate();
				window.ESWRAnnotationCMD.execute();
				CommandManager.executed.push(window.ESWRAnnotationCMD); 
			}
		}
	};
		
	return CommandManager;
})();

var generateUUID = function () {
    var d = new Date().getTime();
    var uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
        var r = (d + Math.random() * 16) % 16 | 0;
        d = Math.floor(d / 16);
        return (c == 'x' ? r : (r & 0x7 | 0x8)).toString(16);
    });
    return uuid;
};

(function ($) {

    var defaults = { color: 'red', width: 4, opacity: .5 };

    $.fn.ESWRAnnotate = function (options) {
        var settings = $.extend({}, defaults, options || {});

        var self = this;
		
		window.ESWRAnnotationSelf = self;
		
        this.setOptions = function (options) {
            settings = $.extend(settings, options);
        };

        this.removeLastPath = function () {
            if (self.paths.length > 0) {
                localStorage.clear();
                paper.projects[0].clear();
                self.paths.pop();
                savePaths();
                self.paths = [];
                renderPaths();
            }
        }

		/*
        window.onkeydown = function (e) {
			return true;
			
			if (window.ESWRAnnotationInDialog == 0) {
				return !(e.keyCode == 32);
			} else {
				return true;
			}
			
        };
		*/

        window.onload = function () {

            $(self).each(function (eachIndex, eachItem) {
                self.paths = [];

                var img = eachItem;

                // Get a reference to the canvas object
                //var canvas = $('#myCanvas')[0];
                var canvas = $('<canvas>')
                    .attr({
                        width: $(img).width(),
                        height: $(img).height()
                    })
                    .addClass('image-markup-canvas')
                    .css({
                        position: 'absolute',
                        top: '0px',
                        left: '0px'
                    });

                $(img).after(canvas);

                $(img).data('paths', []);

                // Create an empty project and a view for the canvas:
                paper.setup(canvas[0]);

                $(canvas).mouseenter(function () {
                    paper.projects[eachIndex].activate();
                });

                // Create a simple drawing tool:
                var tool = new paper.Tool();

				if (settings.width > 0) {
					tool.onMouseMove = function (event) {
	//					window.ESWRAnnotationClickCounter = 0;
						if (!$('.context-menu-list').is(':visible')) {
							position = event.point;
							paper.project.activeLayer.selected = false;
							self.setPenColor(settings.color);
							if (event.item) {
								event.item.selected = true;
								selectedItem = event.item;
								self.setCursorHandOpen();
							}
							else {
								selectedItem = null;
							}
						}
					}
                }

				if (settings.width > 0) {
					tool.onMouseDown = function (event) {
	//					alert('onMouseDown');
						switch (event.event.button) {
							case 0:  // leftclick
								{
									window.ESWRAnnotationClickCounter++;
									if (window.ESWRAnnotationClickCounter == 1)
									{
										singleClickTimer = setTimeout(function() {
													window.ESWRAnnotationClickCounter = 0;
												}, 400);
									}
									
									// If we produced a path before, deselect it:
									if (path) {
										path.selected = false;
									}
									path = new paper.Path();
									path.data.uuid = generateUUID();
									path.strokeColor = settings.color;
									path.strokeWidth = settings.width;
									path.opacity = settings.opacity;
								}
								break;
							case 2:  // rightclick
								break;
						}
					}
                }

				if (settings.width > 0) {
					tool.onMouseDrag = function (event) {
						switch (event.event.button) {
							// leftclick
							case 0:
								// Every drag event, add a point to the path at the current
								// position of the mouse:

	//							window.ESWRAnnotationClickCounter = 0;
								
								if (selectedItem) {
									if (!mouseDownPoint)
										mouseDownPoint = selectedItem.position;

									self.setCursorHandClose();
									selectedItem.position = new paper.Point(
										selectedItem.position.x + event.delta.x,
										selectedItem.position.y + event.delta.y);

								}
								else if (path) {

									if (paper.Key.isDown('s')) {
										if (path.segments.length <= 1)   // A bug in paper.js, had to use <= 1
										{
											path.add(event.point);
										} else {
											path.lastSegment.point = event.point;
											if (path.segments.length > 2) {
												path.removeSegments(1,path.segments.length-1);  // Clean path before was forcing to be straight
											};
										};
										
									} else {
										path.add(event.point);
									};

								}
								break;
								// rightclick
							case 2:
								break;
						}
					}
                }

				if (settings.width > 0) {
					tool.onMouseUp = function (event) {
						switch (event.event.button) {
							// leftclick
							case 0:
								
								//To make it a straight line.
								//path.add(event.point);  // To ensure the last point is added
								//path.removeSegments(1, path.segments.length-1);
								
								if (selectedItem) {
	//2								window.ESWRAnnotationClickCounter = 0;
									if (mouseDownPoint) {
										var selectedItemId = selectedItem.data.uuid;
										var draggingStartPoint = { x: mouseDownPoint.x, y: mouseDownPoint.y };
										var draggingEndPoint =  {x: selectedItem.position.x, y: selectedItem.position.y };
										
										CommandManager.AddAsExecuted({
											project: paper.project ,
											execute: function () {
												
												var j_item = paper.project.getItem({ data: {uuid: selectedItemId}});
												if ((typeof(j_item) != 'undefined') && (j_item != null)) {
													if (j_item.segments) {
														j_item.position = new paper.Point(draggingEndPoint.x, draggingEndPoint.y);
													} else {
														j_item.position = draggingEndPoint;
													}
												};
												
											},
											unexecute: function () {
												
												var j_item = paper.project.getItem({ data: {uuid: selectedItemId}});
												if ((typeof(j_item) != 'undefined') && (j_item != null)) {
													if (j_item.segments) {
														j_item.position = new paper.Point(draggingStartPoint.x, draggingStartPoint.y);
													} else {
														j_item.position = draggingStartPoint;
													}
												};
												
											}
										});
										
										mouseDownPoint = null;
										self.setCursorHandOpen();
									} else {
										//Click on Text
										if (selectedItem.className == 'PointText') {
											if (window.ESWRAnnotationClickCounter > 1) {
												window.ESWRAnnotationClickCounter = 0;
												
												//Edit Text 
												window.ESWRAnnotationLatestUUID  = selectedItem.data.uuid;
												window.ESWRAnnotationTextCurrent = selectedItem.content;
												
//alert(window.ESWRAnnotationTextCurrent);
												
												window.ESWRAnnotationFontNameCurrent = selectedItem.fontFamily;
												window.ESWRAnnotationFontBoldCurrent = (selectedItem.fontWeight == 'bold' ? 1 : 0);
												window.ESWRAnnotationFontSizeCurrent = selectedItem.fontSize;
												
												var j_FillColor_Red = (Math.round(selectedItem.fillColor.red * 100) / 100);
												var j_FillColor_Green = (Math.round(selectedItem.fillColor.green * 100) / 100);
												var j_FillColor_Blue = (Math.round(selectedItem.fillColor.blue * 100) / 100);

												if ((j_FillColor_Red == 1) && (j_FillColor_Green == 0) && (j_FillColor_Blue == 0)) {
													window.ESWRAnnotationFontColorCurrent = 'Red';
												} else if ((j_FillColor_Red == 0) && (j_FillColor_Green == 0.5) && (j_FillColor_Blue == 0)) {
													window.ESWRAnnotationFontColorCurrent = 'Green';
												} else if ((j_FillColor_Red == 0) && (j_FillColor_Green == 0) && (j_FillColor_Blue == 1)) {
													window.ESWRAnnotationFontColorCurrent = 'Blue';
												} else if ((j_FillColor_Red == 1) && (j_FillColor_Green == 1) && (j_FillColor_Blue == 0)) {
													window.ESWRAnnotationFontColorCurrent = 'Yellow';
												} else {
													window.ESWRAnnotationFontColorCurrent = 'Black';
												}
												
												window.ESWRAnnotationFontOpacityCurrent = selectedItem.opacity;
												window.ESWRAnnotationTextNew     = window.ESWRAnnotationTextCurrent;
												window.ESWRAnnotationFontNameNew = window.ESWRAnnotationFontNameCurrent;
												window.ESWRAnnotationFontBoldNew = window.ESWRAnnotationFontBoldCurrent;
												window.ESWRAnnotationFontSizeNew = window.ESWRAnnotationFontSizeCurrent;
												window.ESWRAnnotationFontColorNew = window.ESWRAnnotationFontColorCurrent;
												window.ESWRAnnotationFontOpacityNew = window.ESWRAnnotationFontOpacityCurrent;
												window.ESWRAnnotationNewTextPositionX = 0;
												window.ESWRAnnotationNewTextPositionY = 0;
												window.ESWRAnnotationInDialog = 1;
												$("#ESWRAnnotationText").val(window.ESWRAnnotationTextCurrent);
												$("#ESWRAnnotationFontName").val(window.ESWRAnnotationFontNameCurrent);
												$("#ESWRAnnotationFontBold").prop( "checked", (window.ESWRAnnotationFontBoldCurrent == 1 ? true : false) );
												$("#ESWRAnnotationFontSize").val(window.ESWRAnnotationFontSizeCurrent);
												$("#ESWRAnnotationFontColor").val(window.ESWRAnnotationFontColorCurrent);
												$("#ESWRAnnotationFontOpacity").val(window.ESWRAnnotationFontOpacityCurrent);
												window.ESWRAnnotationDialog.dialog({position: {my: 'left+'+event.event.clientX+' top+'+event.event.clientY, at: 'left top' ,of: window}});
												window.ESWRAnnotationDialog.dialog('open');
												
											}
										}
									}
								} else {
									// When the mouse is released, simplify it:
									
//									alert(path.length);
									
									if (path.length > 2) {
										path.simplify();
										path.remove();
										var strPath = path.exportJSON({ asString: true });
										var j_uuid = generateUUID();
										CommandManager.execute({
											project: paper.project ,
											execute: function () {
												path = new paper.Path();
												path.importJSON(strPath);
												path.data.uuid = j_uuid;
											},
											unexecute: function () {
												var j_item = paper.project.getItem({ data: {uuid: j_uuid}});
												if ((typeof(j_item) != 'undefined') && (j_item != null)) { j_item.remove(); };
											}
										});
									} else {
										path.remove();
									};
									
									if (window.ESWRAnnotationClickCounter > 1) {
										// New Text
										window.ESWRAnnotationLatestUUID  = '';
										window.ESWRAnnotationTextCurrent = '';
										window.ESWRAnnotationTextNew     = '';
										
										window.ESWRAnnotationFontNameCurrent = $('#ESWRAnnotationLatestTextFontName').val();
										window.ESWRAnnotationFontBoldCurrent = parseInt($('#ESWRAnnotationLatestTextFontBold').val());
										window.ESWRAnnotationFontSizeCurrent = parseInt($('#ESWRAnnotationLatestTextFontSize').val());
										window.ESWRAnnotationFontColorCurrent = $('#ESWRAnnotationLatestTextFontColor').val();
										window.ESWRAnnotationFontOpacityCurrent = Number($('#ESWRAnnotationLatestTextFontOpacity').val());
										
										window.ESWRAnnotationFontNameNew = window.ESWRAnnotationFontNameCurrent;
										window.ESWRAnnotationFontBoldNew = window.ESWRAnnotationFontBoldCurrent;
										window.ESWRAnnotationFontSizeNew = window.ESWRAnnotationFontSizeCurrent;
										window.ESWRAnnotationFontColorNew = window.ESWRAnnotationFontColorCurrent;
										window.ESWRAnnotationFontOpacityNew = window.ESWRAnnotationFontOpacityCurrent;
										
										window.ESWRAnnotationNewTextPositionX = event.point.x;
										window.ESWRAnnotationNewTextPositionY = event.point.y;
										window.ESWRAnnotationInDialog = 1;
										$("#ESWRAnnotationText").val(window.ESWRAnnotationTextCurrent);
										$("#ESWRAnnotationFontName").val(window.ESWRAnnotationFontNameCurrent);
										$("#ESWRAnnotationFontBold").prop( "checked", (window.ESWRAnnotationFontBoldCurrent == 1 ? true : false) );
										$("#ESWRAnnotationFontSize").val(window.ESWRAnnotationFontSizeCurrent);
										$("#ESWRAnnotationFontColor").val(window.ESWRAnnotationFontColorCurrent);
										$("#ESWRAnnotationFontOpacity").val(window.ESWRAnnotationFontOpacityCurrent);
										
										window.ESWRAnnotationDialog.dialog({position: {my: 'left+'+event.event.clientX+' top+'+event.event.clientY, at: 'left top' ,of: window}});
										window.ESWRAnnotationDialog.dialog('open');
										
									}
									
								}
								break;
								// rightclick
							case 2:
								contextPoint = event.point;
	//                            contextSelectedItemId = selectedItem ? selectedItem.data.uuid : '';
								break;
						}
					}
                }

				if (settings.width > 0) {
					tool.onKeyUp = function (event) {
						if (window.ESWRAnnotationInDialog == 0) {
							if (selectedItem) {
								// When a key is released, set the content of the text item:
		//                        if (selectedItem.content) {
								if (selectedItem.className == 'PointText') {
									//The backspace button in FireFox and Chrome tells the browser to go back a page. So the best is to not promote editing text directly. Also this is not writing in the undo / redo queue
									
									if (event.key == 'delete') {
										self.erase();
										//paper.view.update();  // work around FireFox bug
									} else if (event.key == 'u') {
										CommandManager.undo();
										paper.view.update();
									} else if (event.key == 'r') {
										CommandManager.redo();
										paper.view.update();
									} else {
									}
									
								} else {
									//A Path
									if (event.key == 'delete') {
										self.erase();
										//paper.view.update();  // work around FireFox bug
									} else if (event.key == 'u') {
										CommandManager.undo();
										paper.view.update();
									} else if (event.key == 'r') {
										CommandManager.redo();
										paper.view.update();
									}
								}
							} else {
								//Nothing Selected
								
	//							if (!($(':text').is(':focus'))) {
								
								if (!($(':text').is(':focus') || $('textarea').is(':focus'))) {
									if (event.key == 'u') {
										CommandManager.undo();
										paper.view.update();
									} else if (event.key == 'r') {
										CommandManager.redo();
										paper.view.update();
									}
									
								}
							}
						}
					}
				}

                // Draw the view now:
                paper.view.update();
				
            });
			ESWR_OnLoadedAnnotations();    //New
			
        }

        var path;
        var position;
        var contextPoint;
//        var contextSelectedItemId;
        var selectedItem;
        var mouseDownPoint;

		if (settings.width > 0) {
			this.erase = function () {
				if (selectedItem.className == 'PointText') {
					//Text
					
					var contextSelectedItemId;
					contextSelectedItemId = selectedItem ? selectedItem.data.uuid : '';
					
					var j_text_pos_x      = selectedItem.position.x;
					var j_text_pos_y      = selectedItem.position.y;
					var j_text_content    = selectedItem.content;
					var j_text_uuid       = selectedItem.data.uuid;
					var j_text_fontFamily = selectedItem.fontFamily;
					var j_text_fontWeight = selectedItem.fontWeight;
					var j_text_fontSize   = selectedItem.fontSize;
					var j_text_fillColor  = selectedItem.fillColor;
					var j_text_opacity    = selectedItem.opacity;
					
					CommandManager.execute({
						project: paper.project ,
						execute: function () {
							
							var j_item = paper.project.getItem({ data: {uuid: contextSelectedItemId}});
							if ((typeof(j_item) != 'undefined') && (j_item != null)) { j_item.remove(); };
							
						},
							
						unexecute: function () {
							var j_pos;
							j_pos = new paper.Point(j_text_pos_x,j_text_pos_y);
							
							var text = new paper.PointText(j_pos);
							
							text.content = j_text_content;
							text.fontFamily = j_text_fontFamily;
							text.fontWeight = j_text_fontWeight;
							text.fontSize = j_text_fontSize;
							text.fillColor = j_text_fillColor;
							text.opacity = j_text_opacity;
							text.data.uuid = j_text_uuid;
						}
					});
				
				} else {
					//Path
					var strPathArray = new Array();
					var contextSelectedItemId;
					
					contextSelectedItemId = selectedItem ? selectedItem.data.uuid : '';
					
					var j_item = paper.project.getItem({ data: {uuid: contextSelectedItemId}});
					if ((typeof(j_item) != 'undefined') && (j_item != null)) {
						var strPath =j_item.exportJSON({ asString: true });
						strPathArray.push(strPath);
					};
					
					
					CommandManager.execute({
						project: paper.project ,
						execute: function () {
							var j_item = paper.project.getItem({ data: {uuid: contextSelectedItemId}});
							if ((typeof(j_item) != 'undefined') && (j_item != null)) { j_item.remove(); };
						},
						unexecute: function () {
							$(strPathArray).each(function (index, strPath) {
								path = new paper.Path();
								path.importJSON(strPath);
								path.data.uuid = contextSelectedItemId;
							});
						}
					});

					
				};
				paper.view.update();
				
				selectedItem = null;
				self.setPenColor(settings.color);
			}
        }

   		if (settings.width > 0) {
			this.downloadCanvas = function (canvas, filename) {

				/// create an "off-screen" anchor tag
				var lnk = document.createElement('a'),
					e;

				/// the key here is to set the download attribute of the a tag
				lnk.download = filename;

				/// convert canvas content to data-uri for link. When download
				/// attribute is set the content pointed to by link will be
				/// pushed as "download" in HTML5 capable browsers
				lnk.href = canvas.toDataURL();

				/// create a "fake" click-event to trigger the download
				if (document.createEvent) {

					e = document.createEvent("MouseEvents");
					e.initMouseEvent("click", true, true, window,
									 0, 0, 0, 0, 0, false, false, false,
									 false, 0, null);

					lnk.dispatchEvent(e);

				} else if (lnk.fireEvent) {

					lnk.fireEvent("onclick");
				}
			}
			
			this.download = function () {
				var canvas = paper.project.activeLayer.view.element;
				var img = $(canvas).parent().find('img')[0];
				var mergeCanvas = $('<canvas>')
				.attr({
					width: $(img).width(),
					height: $(img).height()
				});
				
				var mergedContext = mergeCanvas[0].getContext('2d');
				mergedContext.clearRect(0, 0, $(img).width(), $(img).height());
				mergedContext.drawImage(img, 0, 0);
				
				mergedContext.drawImage(canvas, 0, 0);
				
				self.downloadCanvas(mergeCanvas[0], "image.png");
			}
			
			this.DownloadImage = function (j_ImageNumber,j_Image_Width,j_Image_Height) {
				//var canvas = paper.project.activeLayer.view.element;
				var canvas = paper.projects[j_ImageNumber].activeLayer.view.element;
				
				var img = $(canvas).parent().find('img')[0];
				var mergeCanvas = $('<canvas>')
				.attr({
					width: j_Image_Width+'px',
					height: j_Image_Height+'px'
				});
				
				var mergedContext = mergeCanvas[0].getContext('2d');
				mergedContext.clearRect(0, 0, j_Image_Width, j_Image_Height);
				mergedContext.drawImage(img, 0, 0);
				
				mergedContext.drawImage(canvas, 0, 0);
				
				self.downloadCanvas(mergeCanvas[0], "image.png");
			}
			
			this.PrepareFlattened = function (j_ImageNumber,j_ObjectNameFlattenedImage,j_Image_Width,j_Image_Height) {
				var canvas = paper.projects[j_ImageNumber].activeLayer.view.element;
				var img = $(canvas).parent().find('img')[0];
				var mergeCanvas = $('<canvas>')
				.attr({
					width: j_Image_Width+'px',
					height: j_Image_Height+'px'
				});
				
				var mergedContext = mergeCanvas[0].getContext('2d');
				mergedContext.clearRect(0, 0, j_Image_Width, j_Image_Height);
				mergedContext.drawImage(img, 0, 0);

				mergedContext.drawImage(canvas, 0, 0);

				//self.downloadCanvas(mergeCanvas[0], "image-markup.png");
				
				
				var dataURL = mergeCanvas[0].toDataURL();
				//$('#FlattenedImage').text(dataURL);
				//alert('step4'+dataURL);
				
				$('#'+j_ObjectNameFlattenedImage).text(dataURL);
				
				
			}

			this.setPenColor = function (color) {
				self.setOptions({ color: color.toLowerCase()});
				$('.image-markup-canvas').css('cursor', "url(scripts/Annotate_1_0/" + color.toLowerCase() + "-pen.png) 14 50, auto");
				$('#ESWRAnnotationLatestPenColor').val(color);
				window.ESWR_CurrentAnnotateCursor = 1;  //Pen
			}

			this.setPenWidth = function (width) {
				self.setOptions({ width: width });
				$('#ESWRAnnotationLatestPenWidth').val(width.toString());
			}

			this.setPenOpacity = function (opacity) {
				self.setOptions({ opacity: opacity });
				$('#ESWRAnnotationLatestPenOpacity').val(opacity.toString());
			}

			this.setCursorHandOpen = function () {
				$('.image-markup-canvas').css('cursor', "url(scripts/Annotate_1_0/hand-open.png) 25 25, auto");
				window.ESWR_CurrentAnnotateCursor = 2;  //Open Hand
			}

			this.setCursorHandClose = function () {
				$('.image-markup-canvas').css('cursor', "url(scripts/Annotate_1_0/hand-close.png) 25 25, auto");
				window.ESWR_CurrentAnnotateCursor = 3;  //Closed Hand
			}

			$.contextMenu({
				selector: '.image-markup-canvas',
				callback: function (key, options) {
					switch (key) {
						//COMMANDS
						case 'undo':
							CommandManager.undo();
							paper.view.update();  // work around FireFox bug. Had to call from this level of execution
							break;
						case 'redo':
							CommandManager.redo();
							paper.view.update();  // work around FireFox bug. Had to call from this level of execution
							break;
						case 'erase':
							self.erase();
							paper.view.update();  // work around FireFox bug. Had to call from this level of execution
							break;
						//case 'download':
						//	self.download();
						//	break;
							//PENS
						//case 'blackPen':
						//	self.setPenColor('Black');
						//	break;
						//case 'redPen':
						//	self.setPenColor('Red');
						//	break;
						//case 'greenPen':
						//	self.setPenColor('Green');
						//	break;
						//case 'bluePen':
						//	self.setPenColor('Blue');
						//	break;
						//case 'yellowPen':
						//	self.setPenColor('Yellow');
						//	break;
					}
				},
				items: {
					"undo": { name: "Undo", icon: "undo" },
					"redo": { name: "Redo", icon: "redo" },
					"erase": { name: "Erase", icon: "erase" },
					//"download": { name: "Download", icon: "download" },
					//"sep1": "---------",
					//"blackPen": { name: "Black Pen", icon: "blackpen" },
					//"redPen": { name: "Red Pen", icon: "redpen" },
					//"greenPen": { name: "Green Pen", icon: "greenpen" },
					//"bluePen": { name: "Blue Pen", icon: "bluepen" },
					//"yellowPen": { name: "Yellow Pen", icon: "yellowpen" },
				}
			
			});
		};
    };
}(jQuery));

