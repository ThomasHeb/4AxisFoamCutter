import Cocoa
import SceneKit
import SwiftUI



class ViewController: NSViewController, FCalcCallback {
    
    var     appDelegate:    AppDelegate!
    var     fcalc:          FCalc!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        // get a reference to the App
        appDelegate     = NSApplication.shared.delegate as? AppDelegate
        // get a reference to the fcalc
        fcalc           = appDelegate.fcalc
        // callback is performed here
        fcalc.callback  = self
       
    }
    
    @IBOutlet weak var settingsTableView: NSTableView!
    @IBOutlet weak var positionsTableViewHeader: NSTableHeaderView!
    @IBOutlet weak var positionsTableView: NSTableView!
    @IBOutlet var preview:       SCNView!
    var           scnPreview:    SCNScene!
    
    
      
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Update the tables
        settingsTableView.reloadData()
        positionsTableView.reloadData()
        
        let menu = NSMenu()
        //menu.addItem(NSMenuItem(title: "Edit", action: #selector(tableViewEditItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete line", action: #selector(tableViewDeleteItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Insert line above", action: #selector(tableViewAddBeforItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Insert line below", action: #selector(tableViewAddAfterItemClicked(_:)), keyEquivalent: ""))
        positionsTableView.menu = menu
    
        // Setup the preview
        scnPreview = SCNScene()
        preview.scene = scnPreview
        preview.allowsCameraControl = true
        preview.autoenablesDefaultLighting = true
      // ToDo only for testing
        preview.showsStatistics = true
        
    }

    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    // =========================================================================================
    // MARK: - Callbacks von FCalc
    func updatePositionsTableView(_ atIndex: Int?) {
        if atIndex == nil {
            positionsTableView.reloadData()
        } else {
            positionsTableView.reloadData()// TODO
        }
        var name: String = ""
        for (index, c) in self.positionsTableView.tableColumns.enumerated() {
            switch index {
            case 0: name = "ID";                                               break
            case 1: name = "Pretravel";                                        break
            case 2: name = "Hotwire";                                          break
            case 3: name = "Axis "  + fcalc.valueForKey(.labelX1Axis);         break
            case 4: name = "Axis "  + fcalc.valueForKey(.labelY1Axis);         break
            case 5: name = "Axis "  + fcalc.valueForKey(.labelX2Axis);         break
            case 6: name = "Axis "  + fcalc.valueForKey(.labelY2Axis);         break
            
            
            /*
            case 3: name = "Shape " + fcalc.valueForKey(.labelX1Axis);          break
            case 4: name = "Shape " + fcalc.valueForKey(.labelY1Axis);          break
            case 5: name = "Shape " + fcalc.valueForKey(.labelX2Axis);          break
            case 6: name = "Shape " + fcalc.valueForKey(.labelY2Axis);          break
            case 7: name = "Axis "  + fcalc.valueForKey(.labelX1Axis);          break
            case 8: name = "Axis "  + fcalc.valueForKey(.labelY1Axis);          break
            case 9: name = "Axis "  + fcalc.valueForKey(.labelX2Axis);          break
            case 10: name = "Axis "  + fcalc.valueForKey(.labelY2Axis);         break
            case 11: name = "Block " + fcalc.valueForKey(.labelX1Axis);         break
            case 12: name = "Block " + fcalc.valueForKey(.labelY1Axis);         break
            case 13: name = "Block " + fcalc.valueForKey(.labelX2Axis);         break
            case 14: name = "Block " + fcalc.valueForKey(.labelY2Axis);         break
            */
            default: name = ""
            }
            c.headerCell.stringValue    = name
        }
     }
    
    func updatePreview(_ node: SCNNode) {
        if node.parent != scnPreview.rootNode {
            scnPreview.rootNode.addChildNode(node)
        }
    }
    func updateSettingsTableView() {
        settingsTableView.reloadData()
    }
    
    // Buttons
    
    @IBAction func setCameraTop(_ sender: Any) {
        // delete the user temporary camera
        preview.pointOfView = nil
        fcalc.setCamera(.top)
    }
    @IBAction func setCameraFront(_ sender: Any) {
        // delete the user temporary camera
        preview.pointOfView = nil
        fcalc.setCamera(.front)
    }
    @IBAction func setCameraLeft(_ sender: Any) {
        // delete the user temporary camera
        preview.pointOfView = nil
        fcalc.setCamera(.left)
    }
    @IBAction func setCameraRight(_ sender: Any) {
        // delete the user temporary camera
        preview.pointOfView = nil
        fcalc.setCamera(.right)
    }
    @IBAction func setCameraHome(_ sender: Any) {
        // delete the user temporary camera
        preview.pointOfView = nil
        fcalc.setCamera(.home)
    }
    
    
    
    
}



protocol SettingsTableViewCellCallback {
    func newValueforKey(_ key: FCalc.SettingsTableKey, value: String?)
    func shouldChangeToValueforKey(_ key: FCalc.SettingsTableKey, value: String?) -> Bool
}
class SettingsTableViewCell: NSTableCellView {
    var label:          String?         = nil
    var value:          String?         = nil
    var key:            FCalc.SettingsTableKey       = .none
    var color:          NSColor?        = nil
    var isEditable:     Bool            = false
    
    
    var callback:       SettingsTableViewCellCallback? = nil
}

class SettingsHeaderCell: SettingsTableViewCell {
    @IBOutlet weak var textLabel: NSTextField!
    override func awakeFromNib() {
        super.awakeFromNib()
        // initialize
    }
    override func viewWillDraw() {
        super .viewWillDraw()
        textLabel.stringValue   = label ?? ""
    }
}

class SettingsLabelCell: SettingsTableViewCell {
    @IBOutlet weak var textLabel: NSTextField!
    override func awakeFromNib() {
        super.awakeFromNib()
        // initialize
    }
    override func viewWillDraw() {
        super .viewWillDraw()
        textLabel.stringValue   = label ?? ""
    }
}

class SettingsValueCell: SettingsTableViewCell, NSTextViewDelegate, NSTextDelegate {
    @IBOutlet weak var textView: NSTextView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // initialize
        textView?.delegate      = self
    }
    override func viewWillDraw() {
        super .viewWillDraw()
        textView.string         = value ?? ""
        textView?.isEditable    = isEditable
    }
    func textDidEndEditing(_ obj: Notification) {
        if let f = callback?.newValueforKey(_:value:) {
            f(key, textView.string)
        }
    }
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if replacementString == "\n" {
            if let f = callback?.newValueforKey(_:value:) {
                f(key, textView.string)
            }
            return false
        }
        
        let repString   = replacementString ?? ""
        let nsString    = textView.string as NSString?
        let newString   = nsString?.replacingCharacters(in: affectedCharRange, with: repString)
        
        if let f = callback?.shouldChangeToValueforKey(_:value:) {
            return f(key, newString)
        }
        return false
    }
}


class SettingsCheckBoxCell: SettingsTableViewCell {
    @IBOutlet weak var checkBox: NSButton!
    override func awakeFromNib() {
        super.awakeFromNib()
        // initialize
    }
    override func viewWillDraw() {
        super .viewWillDraw()
        checkBox.state          = .off
        if value == "1" {
            checkBox.state      = .on
        }
    }
    @IBAction func onCheckBox(_ sender: Any) {
        if checkBox.state == .on {
            value = "1"
        } else {
            value = "0"
        }
        if let f = callback?.newValueforKey(_:value:) {
            f(key, value)
        }
    }
}


protocol ContentTableViewCellCallback {
    func newValueforKey(_ key: FCalc.PositionTableKey, index: Int?, value: String?)
    func shouldChangeToValueforKey(_ key: FCalc.PositionTableKey,  index: Int?, value: String?) -> Bool
}
class ContentTableViewCell: NSTableCellView {
    var value:          String?                         = nil
    var key:            FCalc.PositionTableKey                = .none
    var index:          Int?                            = nil
    var callback:       ContentTableViewCellCallback?   = nil
}
class ContentLabelCell: ContentTableViewCell {
    @IBOutlet weak var textLabel: NSTextField!
    override func awakeFromNib() {
        super.awakeFromNib()
        // initialize
    }
    override func viewWillDraw() {
        super .viewWillDraw()
        textLabel.stringValue   = value ?? ""
    }
}
class ContentValueCell: ContentTableViewCell, NSTextViewDelegate, NSTextDelegate {
    @IBOutlet weak var textView: NSTextView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // initialize
        textView?.delegate      = self
    }
    override func viewWillDraw() {
        super .viewWillDraw()
        textView.string         = value ?? ""
    }
    
    func textDidEndEditing(_ notification: Notification) {
        if let f = callback?.newValueforKey(_:index:value:) {
            f(key, index, textView.string)
        }
    }
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if replacementString == "\n" {
            if let f = callback?.newValueforKey(_:index:value:) {
                f(key, index, textView.string)
            }
            return false
        }
        
        let repString   = replacementString ?? ""
        let nsString    = textView.string as NSString?
        let newString   = nsString?.replacingCharacters(in: affectedCharRange, with: repString)
        
        if let f = callback?.shouldChangeToValueforKey(_:index:value:) {
            return f(key, index, newString)
        }
        return false
    }
}
class ContentCheckBoxCell: ContentTableViewCell {
    @IBOutlet weak var checkBox: NSButton!
    override func awakeFromNib() {
        super.awakeFromNib()
        // initialize
        
    }
    override func viewWillDraw() {
        super .viewWillDraw()
        checkBox.state          = .off
        if value == "1" {
            checkBox.state      = .on
        }
    }
    @IBAction func onCheckBox(_ sender: Any) {
        if checkBox.state == .on {
            value = "1"
        } else {
            value = "0"
        }
       
        if let f = callback?.newValueforKey(_:index:value:) {
            f(key, index, value)
        }
    }
}

extension ViewController: NSTableViewDataSource, NSTableViewDelegate, SettingsTableViewCellCallback, ContentTableViewCellCallback {
   
    
    
    fileprivate enum CellIdentifiers {
        static let SettingsHeaderCell   =  "SettingsHeaderCell"
        static let SettingsLabelCell    =  "SettingsLabelCell"
        static let SettingsValueCell    =  "SettingsValueCell"
        static let SettingsCheckBoxCell =  "SettingsCheckBoxCell"
        
        static let ContentLabelCell     =  "ContentLabelCell"
        static let ContentValueCell     =  "ContentValueCell"
        static let ContentCheckBoxCell  =  "ContentCheckBoxCell"
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == settingsTableView {
            return appDelegate.settings.count
        }
        if tableView == positionsTableView {
            return fcalc.numberOfPositions
        }
        return 0
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == settingsTableView {
            var cellIdentifier:     String      = ""
            
            let key         = appDelegate.settings[row]
            let dataType    = fcalc.dataTypeForKey(key)
            let isEditable  = fcalc.isEditableForKey(key)
            let label       = fcalc.labelForKey(key)
            let value       = fcalc.valueForKey(key)
            
            if tableColumn == tableView.tableColumns[0] {
                switch (dataType) {
                case .header:
                    cellIdentifier  = CellIdentifiers.SettingsHeaderCell
                    break;
                default:
                    cellIdentifier  = CellIdentifiers.SettingsLabelCell
                    break;
                }
                
            } else if tableColumn == tableView.tableColumns[1] {
                switch (dataType) {
                case .header:
                    cellIdentifier  = ""
                    break;
                case .boolean:
                    cellIdentifier  = CellIdentifiers.SettingsCheckBoxCell
                    break
                default:
                    cellIdentifier  = CellIdentifiers.SettingsValueCell
                    break;
                }
                
            }
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? SettingsTableViewCell {
                
                cell.key            = key
                cell.value          = value
                cell.label          = label
                cell.isEditable     = isEditable
                cell.callback       = self
                
                return cell
            }
            return nil
        }
        if tableView == positionsTableView {
            var cellIdentifier:     String                  = ""
            var key:                FCalc.PositionTableKey        = .x1Axis
            let index                                       = row
            var value:              String?                 = nil
            
            switch tableColumn {
            case tableView.tableColumns[0]:
                key                 = .none
                value               = String(index)
                cellIdentifier      = CellIdentifiers.ContentLabelCell
                break
            case tableView.tableColumns[1]:
                key                 = .pretravel
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentCheckBoxCell
                break
            case tableView.tableColumns[2]:
                key                 = .hotwire
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentCheckBoxCell
                break
            case tableView.tableColumns[3]:
                key                 = .x1Axis
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
                break
            case tableView.tableColumns[4]:
                key                 = .y1Axis
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
                break
            case tableView.tableColumns[5]:
                key                 = .x2Axis
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
            case tableView.tableColumns[6]:
                key                 = .y2Axis
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
            
            /*
            case tableView.tableColumns[3]:
                key                 = .x1Shape
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
                break
            case tableView.tableColumns[4]:
                key                 = .y1Shape
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
                break
            case tableView.tableColumns[5]:
                key                 = .x2Shape
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
            case tableView.tableColumns[6]:
                key                 = .y2Shape
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
            case tableView.tableColumns[7]:
                key                 = .x1Axis
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
                break
            case tableView.tableColumns[8]:
                key                 = .y1Axis
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
                break
            case tableView.tableColumns[9]:
                key                 = .x2Axis
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
            case tableView.tableColumns[10]:
                key                 = .y2Axis
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
            case tableView.tableColumns[11]:
                key                 = .x1Block
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
                break
            case tableView.tableColumns[12]:
                key                 = .y1Block
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
                break
            case tableView.tableColumns[13]:
                key                 = .x2Block
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
            case tableView.tableColumns[14]:
                key                 = .y2Block
                value               = fcalc.valueFor(key, index: index)
                cellIdentifier      = CellIdentifiers.ContentValueCell
            */
            default:
                return nil
            }
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? ContentTableViewCell {
                cell.key            = key
                cell.index          = index
                cell.value          = value
                cell.callback       = self
                return cell
            }
            return nil
            
        }
        
        return nil
    }
    /*
    @objc private func tableViewAddItemClicked(_ sender: AnyObject) {

        guard tableView.clickedRow >= 0 else { return }

        let item = items[tableView.clickedRow]

        showDetailsViewController(with: item)
    }
 */
    @objc private func tableViewAddBeforItemClicked(_ sender: AnyObject) {
        let index = positionsTableView.clickedRow
        fcalc.addIndex(index)
    }
    @objc private func tableViewAddAfterItemClicked(_ sender: AnyObject) {
        let index = positionsTableView.clickedRow
        fcalc.addIndex(index + 1)
    }
    
    @objc private func tableViewDeleteItemClicked(_ sender: AnyObject) {
        let index = positionsTableView.clickedRow
        fcalc.deleteIndex(index)
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if tableView == positionsTableView {
            fcalc.markedPosition = row
            return true
        }
        
        return false
    }
    
       
    func shouldChangeToValueforKey(_ key: FCalc.SettingsTableKey, value: String?) -> Bool {
        return fcalc.isValueValid(key, value: value)
    }
    func newValueforKey(_ key: FCalc.SettingsTableKey, value: String?) {
        // wert aktualisieren
        fcalc.valueForKey(key, value: value)
    }
    
    
    func newValueforKey(_ key: FCalc.PositionTableKey, index: Int?, value: String?) {
        guard let index = index else {
            return
        }
        fcalc.valueFor(key, index: index, value: value)
    }
       
    func shouldChangeToValueforKey(_ key: FCalc.PositionTableKey, index: Int?, value: String?) -> Bool {
        guard let index = index else {
            return false
        }
        return fcalc.isValueValid(key, index: index, value: value)
    }
}




