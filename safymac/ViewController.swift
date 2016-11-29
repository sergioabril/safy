//
//  ViewController.swift
//  safymac
//
//  Created by Sergio Abril Herrero on 23/11/16.
//  Copyright © 2016 Sergio Abril Herrero. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSTextFieldDelegate, NSDraggingDestination {
    
    enum currentLayoutStatus {
        case none
        case encryptText
        case decryptText
    }
    
    @IBOutlet weak var passOne: NSSecureTextField!
    
    @IBOutlet weak var passTwo: NSSecureTextField!
    @IBOutlet weak var buttonDecrypt: NSButton!

    @IBOutlet var textview: NSTextView!
    @IBOutlet weak var buttonCross: UIButton!

    var busyWorking = false
    var busyChangingStatus:Bool = false
    var statusChecker:Timer = Timer()
    var lastStatus:currentLayoutStatus = currentLayoutStatus.none
    
    @IBOutlet weak var buttonQR: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.textview.textColor = NSColor.white

    
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.view.window?.titlebarAppearsTransparent = true
        self.view.window?.isMovableByWindowBackground = true
        let colorfondo:NSColor! = NSColor.init(hue: 201.0/360.0, saturation: 81.0/100.0, brightness: 61.0/100.0, alpha: 0.95)
        self.view.window?.backgroundColor = colorfondo
        self.view.window?.isOpaque = false
        
        //self.blur(view: self.view.window?.contentView)
        self.passOne.delegate = self
        self.passTwo.delegate = self

        //Boton
        let colorboton:NSColor! = NSColor.init(hue: 201.0/360.0, saturation: 81.0/100.0, brightness: 61.0/100.0, alpha: 1)
        self.buttonDecrypt.image = NSImage.swatchWithColor(color: colorboton, size: NSMakeSize(380, 40) )
        self.buttonDecrypt.alternateImage = NSImage.swatchWithColor(color: NSColor.white, size: NSMakeSize(380, 40) )
        
        //Reset timer to check the layout
        statusChecker.invalidate()
        statusChecker = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(self.checkStatusChange), userInfo: nil, repeats: true)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    

    private func blur(view: NSView!) {
        let blurView:NSView! = NSView(frame: view.bounds)
        blurView.wantsLayer = true
        blurView.layer!.backgroundColor = NSColor.clear.cgColor
        blurView.layer!.masksToBounds = true
        blurView.layerUsesCoreImageFilters = true
        blurView.layer!.needsDisplayOnBoundsChange = true
        
        let satFilter:CIFilter! = CIFilter(name: "CIColorControls")
        satFilter.setDefaults()
        satFilter.setValue(NSNumber(value: 2.0), forKey: "inputSaturation")
        
        let blurFilter:CIFilter! = CIFilter(name: "CIGaussianBlur")
        blurFilter.setDefaults()
        blurFilter.setValue(NSNumber(value: 2.0), forKey: "inputRadius")
        
        blurView.layer?.backgroundFilters = [satFilter, blurFilter]
        
        view.addSubview(blurView)
        
        blurView.layer!.needsDisplay()
    }

    func compressText(){
            //Check if passwords are null
            if self.passOne.stringValue.characters.count < 1{
                showMessage(isError: true, text: "Contraseña vacía", warnuser: true)
                unmarkBusy()
                return;
            }else{
                print("Using password:\(self.passOne.stringValue)")
            }
            
            //Check if passwords are equal
            if(self.passOne.stringValue != self.passTwo.stringValue){
                showMessage(isError: true, text: "Contraseñas no coinciden", warnuser: true)
                unmarkBusy()
                return;
            }
        
            if(textview.string!.characters.count > 0){
                print("El texto a encryptar es \(textview.string!)")
            }else{
                showMessage(isError: true, text: "Texto vacio", warnuser: true)
                unmarkBusy()
                return;
            }
    
            let bytesToEncrypt = textview.string!.utf8.map{$0}
            //print("Bytes to encript \(bytesToEncrypt)");
            
            //Encripto en background
            DispatchQueue.global(qos: .background).async {
           
                let bytesEncryptados = CryptoHelper.encryptAES256fromBytes(databytes: bytesToEncrypt, password: self.passOne.stringValue)
                let cadenaFinal = CryptoHelper.armorHeader.appending(bytesEncryptados.toBase64()!).appending(CryptoHelper.armorFooter)
                
                DispatchQueue.main.async {
                    //Set string to textview
                    self.textview.string = cadenaFinal
                    self.unmarkBusy()
                }
            }

    }
    
    
    func decompressText(){
        
            //Check if passwords are null
            if self.passOne.stringValue.characters.count < 1{
                showMessage(isError: true, text: "Contraseña vacía", warnuser: true)
                unmarkBusy()
                return;
            }else{
                print("Using password:\(self.passOne.stringValue)")
            }
            
            //Avoid empty texts
            if(textview.string == nil){
                showMessage(isError: true, text: "No hay nada que desencriptar", warnuser: true)
                unmarkBusy()
                return;
            }
            
            //Obtengo texto y quito headers y footers. Esa es mi base64
            var newBase64:String! = textview.string!.replacingOccurrences(of: CryptoHelper.armorHeader, with: "")
            newBase64 = newBase64.replacingOccurrences(of: CryptoHelper.armorFooter, with: "")
            
            //COnvierto base64 a data. Si falla suele ser porque esta alterada, asique error y salgo
            let dataToDecrypt:Data? = Data(base64Encoded: newBase64)
            if(dataToDecrypt == nil){
                showMessage(isError: true, text: "Datos corruptos o alterados!", warnuser: true)
                unmarkBusy()
                return
            }
            let bytesToDecrypt:Array<UInt8> = dataToDecrypt!.bytes;
            
            //Desencripto in background
            DispatchQueue.global(qos: .background).async {
                //Decrypt
                let cryptofunction = CryptoHelper.decryptAES256fromBytes(databytes: bytesToDecrypt, password: self.passOne.stringValue)
                let decryptedBytes:Array<UInt8> = cryptofunction.plaintext;
                let decryptionstatus:CryptoHelper.decryptionresult = cryptofunction.status
                print("Decrypted bytes:\(decryptedBytes), status: \(decryptionstatus)")
                if(decryptionstatus == CryptoHelper.decryptionresult.error){
                    DispatchQueue.main.async {
                        //Set string to textview
                        self.showMessage(isError: true, text: "Password wrong or text corrupted (I)", warnuser: true)

                        //Not work anymore
                        self.unmarkBusy()
                    }
                    //Exit
                    return;
                }
                //Ahora mapeo los bytes a caracteres gracias a la extension: "extension UInt8 { var character: Character {... " que he puesto justo despues
                let newstring = decryptedBytes.utf8string
                if(newstring.characters.count == 0){
                    //SInce this was text, and the string given wasn't text, assume the password was wrong or data corrupted
                    DispatchQueue.main.async {
                        self.showMessage(isError: true, text: "Password wrong or text corrupted (II)", warnuser: true)
                        //Not work anymore
                        self.unmarkBusy()
                    }
                    return;
                }
                //Back to main and update text
                DispatchQueue.main.async {
                    //Set string to textview
                    self.textview.string = newstring;
                    //Not work anymore
                    self.unmarkBusy()
                }
            }

    }
    //MARK: Busy and nonbusy. Variable and animations
    func markBusy(){
        busyWorking = true;
    }
    func unmarkBusy(){
        busyWorking = false;
    }
    
    //MARK: Apariencia según estado
    func checkStatusChange(){
        if(busyWorking || busyChangingStatus){return}
        
        if(canDecrypt()){
            //Esta en estado textCanDecrypt. Si el last status no es igual, toca animar
            if(lastStatus != .decryptText){
                lastStatus = .decryptText
                busyChangingStatus = true
                //Anim
                self.buttonDecrypt.title = "Decrypt"
                //self.passOne.alpha = 0
                self.passTwo.isHidden = true
                self.busyChangingStatus = false

            }
        }else{
            //Esta en estado textCanencrypt. Si el last status no es igual, toca animar
            if(lastStatus != .encryptText){
                //Change button and status
                lastStatus = .encryptText
                busyChangingStatus = true
                //Anim
                self.passTwo.isHidden = false
                self.buttonDecrypt.title = "Encrypt"
                //self.passOne.alpha = 1
                self.busyChangingStatus = false
            }
        }
    }
    
    //MARK: Check if valid for decryption
    func canDecrypt() ->Bool{
        var valor:Bool = false;
        if(textview.string?.range(of: CryptoHelper.armorHeader) != nil && textview.string?.range(of: CryptoHelper.armorFooter) != nil){
            //Can be decrypted
            valor = true;
        }
        return valor;
    }
    
    //MARK Button action
    @IBAction func mainButtonAction(_ sender: Any) {
        //Avoid repeating tasks if busy
        if(busyWorking){return}
        //Set for work. Mark as busy and add animations
        markBusy()
        //Work
        if(canDecrypt()){
            decompressText();
        }else{
            compressText();
        }
    }
    
    //MARK Handle Messages
    func showMessage(isError:Bool, text:String, warnuser:Bool){
        //Log to console
        if(isError){
            print("ERROR:\(text)")
        }else{
            print("Aviso:\(text)")
        }
       //Warn user
    }
    
    //MARK: Textfield delegate
    override func controlTextDidBeginEditing(_ obj: Notification) {

    }
    
    

 
}

