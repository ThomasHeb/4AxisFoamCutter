import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    

    // main calclulation class for FoamCutter
    public  var     fcalc:                  FCalc       = FCalc()
    public  let     settings:               [FCalc.SettingsTableKey]     =
                    [ .cutter,
                      .cutterWidth,
                      .cutterHeight,
                      .cutterDepth,
                      .labelX1Axis,
                      .labelY1Axis,
                      .labelX2Axis,
                      .labelY2Axis,
                      .gcodeDecimals,
                      .spacer,
                      .shape,
                      .shapeWidth,
                      .shapeSpacingLeft,
                      .shapeRotationW,
                      .shapeRotationY,
                      .shapeX,
                      .shapeY,
                      .shapeChangeAxis,
                      .shapeMirrorHorizontal,
                      .shapeMirrorVertical,
                      .shapeReverse,
                      .spacer,
                      .block,
                      .blockMaterialComment,
                      .blockWidth,
                      .blockHeight,
                      .blockDepth,
                      .spacer,
                      .blockSpacingLeft,
                      .blockSpacingFront,
                      .blockSpacingUnder,
                      .blockRotation,
                      .spacer,
                      .targetFeedSpeed,
                      .feedSpeedCorrection,
                      .pretravelSpeed,
                      .fastPretravel,
                      .maxFeedSpeed,
                      .spacer,
                      .hotwireSettingComment,
                      .hotwirePower,
                      .hotwirePreheat,
                      .spacer,
                      .preview,
                      .showBlockGraph,
                      .showShapeCutGraph,
                      .showShapeGraph,
                      .showAxisGraph,
                      .showCutterGraph,
                      .simulationSpeed,
                      .previewDiameter
                    ]

    var viewController:             ViewController? = nil
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        // ToDo
        viewController = NSApplication.shared.mainWindow?.windowController?.contentViewController as? ViewController
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    // MARK: - Buttons / Menu
    
    @IBAction func onImport(_ sender: Any) {
        let dialog                     = NSOpenPanel()
        dialog.title                   = "Import a file"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.canChooseDirectories    = false
        dialog.canCreateDirectories    = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes        = fcalc.allowedImportFileTypes

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                let path = result!.path
                _ = fcalc.importShapeFromFile(path)
            }
        } else {
            // User clicked on "Cancel"
        }
        
    }
    @IBAction func onExport(_ sender: Any) {
        let dialog = NSSavePanel();
        
        dialog.title                   = "Export GCODE file";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canCreateDirectories    = false;
        dialog.nameFieldStringValue    = (fcalc.projectName ?? "unknown") + ".gcode"
        dialog.allowedFileTypes        = ["gcode"];

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                let path = result!.path
                _ = fcalc.exportGCodeToFile(path)
            }
        } else {
            // User clicked on "Cancel"
        }
    }
    private var filename:   String?    = nil
    @IBAction func onNew(_ sender: Any) {
        filename = nil
        _ = fcalc.newFile()
    }
    @IBAction func onLoad(_ sender: Any) {
        let dialog                     = NSOpenPanel()
        dialog.title                   = "Load file"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.canChooseDirectories    = false
        dialog.canCreateDirectories    = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes        = fcalc.allowedLoadFileTypes

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                filename = result!.path
                if fcalc.loadFromFile(filename) != 0 {
                    // error on saving the filename
                    filename = nil
                }
            }
        } else {
            // User clicked on "Cancel"
        }
    }
    @IBAction func onSaveAs(_ sender: Any) {
        let dialog = NSSavePanel();
        
        dialog.title                   = "Save file";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canCreateDirectories    = false;
        dialog.nameFieldStringValue    = (fcalc.projectName ?? "unknown") + ".fcf"
        dialog.allowedFileTypes        = fcalc.allowedLoadFileTypes;

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                filename = result!.path
                if fcalc.saveToFile(filename) != 0 {
                    // saving was not ok
                    filename = nil
                }
            }
        } else {
            // User clicked on "Cancel"
        }
    }
    @IBAction func onSave(_ sender: Any) {
        guard let filename = filename else {
            onSaveAs(sender)
            return
        }
        if fcalc.saveToFile(filename) != 0 {
            // error on saving the filename
            self.filename = nil
        }
    }
    
    
    @IBAction func onPlayPause(_ sender: Any) {
        fcalc.playPause()
    }
    @IBAction func onStop(_ sender: Any) {
        fcalc.stop()
    }
    @IBAction func onMergeBefore(_ sender: Any) {
        _ = fcalc.merge(.before)
    }
    @IBAction func onMergeAfter(_ sender: Any) {
        _ = fcalc.merge(.after)
    }
    @IBAction func onDiscard(_ sender: Any) {
       _ = fcalc.discard()
    }
    

}

