//
//  ViewController.swift
//  safyios
//
//  Created by Sergio Abril Herrero on 23/11/16.
//  Copyright © 2016 Sergio Abril Herrero. All rights reserved.
//

import UIKit

let globalcolor = UIColor(hue: 201.0/360.0, saturation: 81.0/100.0, brightness: 61.0/100.0, alpha: 0.95)

class ViewController: UIViewController, UITextFieldDelegate {

    enum currentLayoutStatus {
        case none
        case encryptText
        case decryptText
        case encryptFile
        case decryptFile
    }
    @IBOutlet weak var buttonCross: UIButton!
    
    @IBOutlet weak var buttonQr: UIButton!
    
    @IBOutlet weak var passOne: UITextField!
    @IBOutlet weak var passTwo: UITextField!
    
    @IBOutlet weak var textview: UITextView!
    @IBOutlet weak var buttonDecrypt: UIButton!
    
    @IBOutlet weak var fileimage: UIImageView!
    
    var busyWorking:Bool = false
    var busyChangingStatus:Bool = false
    var statusChecker:Timer = Timer()
    var lastStatus:currentLayoutStatus = currentLayoutStatus.none
    var fileDataPath:URL?
    
    var loader:SALoaderOvalBlur?
    
    let qrscanner:QRCode = QRCode()
    var isCameraScanning:Bool = false;
    var qrview:UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.passOne.delegate = self
        self.passTwo.delegate = self
       
        //INstantiate loader
        self.loader = SALoaderOvalBlur(onView:self.view, radius: 20, blurBackground: true)
        
        //Set AppDelegates reference only once
        let appdel = UIApplication.shared.delegate as! AppDelegate
        if(appdel.mainVC == nil){
            appdel.mainVC = self
            
        }
        
        //set share action to image
        let tapRec = UITapGestureRecognizer()
        tapRec.addTarget(self, action: #selector(ViewController.manageShareType))
        self.fileimage.addGestureRecognizer(tapRec)
        self.fileimage.isUserInteractionEnabled = true
    }
    override func viewWillAppear(_ animated: Bool) {
        //Add notifications for keyboard
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: .UIKeyboardWillHide, object: nil)
        
        //Reset timer to check the layout 
        statusChecker.invalidate()
        statusChecker = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.checkStatusChange), userInfo: nil, repeats: true)
        
        //Test for possible files. But it has to be called from becomeActive (etc) too.
        testForInputFiles()
        
    }

    func testForInputFiles(){
        //SInce this was text, and the string given wasn't text, assume the password was wrong or data corrupted
        if ((UIApplication.shared.delegate as! AppDelegate).openedUrlFile != nil && self.fileDataPath == nil){
            self.fileDataPath = (UIApplication.shared.delegate as! AppDelegate).openedUrlFile!
            //Remove from delegate
            (UIApplication.shared.delegate as! AppDelegate).openedUrlFile = nil
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    //MARK: Compression and decompression
    func compressText(){
        //Check if passwords are null
        if (self.passOne.text!.characters.count < 1 || self.passTwo.text!.characters.count < 1 || self.passOne.text! == "password"){
            showMessage(isError: true, text: "Contraseña vacía o sin cambiar", warnuser: true)
            unmarkBusy()
            return;
        }else{
           // print("Using password:\(self.passOne.text!)")
        }
        
        //Check if passwords are equal
        if(self.passOne.text! != self.passTwo.text!){
            showMessage(isError: true, text: "Contraseñas no coinciden", warnuser: true)
            unmarkBusy()
            return;
        }
        
  
        if(textview.text!.characters.count > 0){
            print("El texto a encryptar es \(textview.text!)")
        }else{
            showMessage(isError: true, text: "Texto vacio", warnuser: true)
            unmarkBusy()
            return;
        }
        
        
        let bytesToEncrypt = textview.text!.utf8.map{$0}
       // print("Bytes to encript \(bytesToEncrypt)");
        
        //Encripto en background
        DispatchQueue.global(qos: .background).async {
            self.lastStatus = .none //reset status so it has to change after compression
            
            let bytesEncryptados = CryptoHelper.encryptAES256fromBytes(databytes: bytesToEncrypt, password: self.passOne.text!)
            let cadenaFinal = CryptoHelper.armorHeader.appending(bytesEncryptados.toBase64()!).appending(CryptoHelper.armorFooter)
            
            let finalUrlOfFile:NSURL = self.saveForSharing(bytes: bytesEncryptados, filetype: nil) //Just note: it ignores the header and footer...
            DispatchQueue.main.async {
                //Set string to textview
                //print("Finished: \(cadenaFinal)")
                self.textview.text = cadenaFinal
                //To avoid the text showing up hide the text
                self.textview.alpha = 0
                self.unmarkBusy()
                //Save url so it
                self.fileDataPath = finalUrlOfFile as URL
                //Share with the url
                //self.shareAsSafyFile(urlpath: finalUrlOfFile)
                //SHare as QR
                //self.shareAsQR(base64string: bytesEncryptados.toBase64()!)
                //Manage kind of share
                self.manageShareType()
            }
        }
        
    }
    func decompressText(){
        
        //Check if passwords are null
        if self.passTwo.text!.characters.count < 1{
            showMessage(isError: true, text: "Contraseña vacía", warnuser: true)
            unmarkBusy()
            return;
        }else{
            print("Using password:\(self.passTwo.text!)")
        }
        
        //2. Check if it's text or a textfile
        //Avoid empty texts if it's a textfile
        if(lastStatus == .decryptText){
            if(textview.text == nil){
                showMessage(isError: true, text: "No hay texto que desencriptar", warnuser: true)
                unmarkBusy()
                return;
            }
        }else if(lastStatus == .decryptFile){
            if(self.fileDataPath == nil){
                showMessage(isError: true, text: "No hay file que desencriptar", warnuser: true)
                unmarkBusy()
                return;
            }
        }

        
        //3. Obtengo data para encryptar. Todo en background
        DispatchQueue.global(qos: .background).async {
            var dataToDecrypt:Data?
            if(self.lastStatus == .decryptText){
                //Obtengo texto y quito headers y footers. Esa es mi base64
                var newBase64:String! = self.textview.text!.replacingOccurrences(of: CryptoHelper.armorHeader, with: "")
                newBase64 = newBase64.replacingOccurrences(of: CryptoHelper.armorFooter, with: "")
                
                //COnvierto base64 a data. Si falla suele ser porque esta alterada, asique error y salgo
                dataToDecrypt = Data(base64Encoded: newBase64)
            }
            if(self.lastStatus == .decryptFile){
                do{
                    try dataToDecrypt = Data(contentsOf: self.fileDataPath!)
                }catch{
                    print("Error convirtiendo file a Data: \(error)")
                    DispatchQueue.main.async {
                        self.showMessage(isError: true, text: "Datos corruptos o alterados! Can't get anyting", warnuser: true)
                        self.unmarkBusy()
                        return
                    }
                }
            }
            
            
            //4. Check if data is nil.. because you can't encrypt. COnvert to bytes
            if(dataToDecrypt == nil){
                DispatchQueue.main.async {
                    self.showMessage(isError: true, text: "Datos corruptos o alterados! Can't get anyting", warnuser: true)
                    self.unmarkBusy()
                    return
                }
            }
            let bytesToDecrypt:Array<UInt8> = dataToDecrypt!.bytes;
            
            //5. Desencripto (in background too)
            //Decrypt
            let cryptofunction = CryptoHelper.decryptAES256fromBytes(databytes: bytesToDecrypt, password: self.passTwo.text!)
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
            
            //Success: remove filepath if there was.
            if(self.fileDataPath != nil){
                print("Borro referencia a:\(self.fileDataPath!)")
                do{
                    try FileManager.default.removeItem(at: self.fileDataPath!)
                }catch{
                    print("Error removing file from inbox. \(error)")
                }
                self.fileDataPath = nil
            }
            
            //Success: Back to main and update text
            DispatchQueue.main.async {
                //Set string to textview
                self.textview.text = newstring;
                //Not work anymore
                self.unmarkBusy()
                //Clean passwords and lose focus
                self.passOne.text = ""
                self.passTwo.text = ""
                self.textview.becomeFirstResponder()
            }
        }
        
    }
    
    
    //MARK: Save data and get URL, so you can share
    func saveForSharing(bytes: Array<UInt8>, filetype: CryptoHelper.fileFormat?) ->NSURL{
        //Data from bytes
        let thedata:Data = Data(bytes)
        //Prepare date
        let date = NSDate()
        let calendar = NSCalendar.current
        let hour = calendar.component(.hour, from: date as Date)
        let minutes = calendar.component(.minute, from: date as Date)
        let secs = calendar.component(.second, from: date as Date)
        //Build Url
        let datestamp:String = "\(hour)-\(minutes)-\(secs)"
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let filepath = "\(documentsPath)/file-\(datestamp).safy"
        //Save to that url
        do{
            try thedata.write(to: NSURL(fileURLWithPath: filepath) as URL)
        }catch{
            print("Error writing safy file to documents dir: \(error)")
        }
        //Return url
        return NSURL(fileURLWithPath: filepath)
    }
    
    //MARK: Busy and nonbusy. Variable and animations. Loader
    func markBusy(){
        busyWorking = true;
        //Show loader
       self.loader?.show()
    }
    func unmarkBusy(){
        busyWorking = false;
        //Remove loader
        self.loader?.hide()
    }
    
    

    //MARK: Apariencia según estado
    func updateButtons(){
        if(self.fileDataPath != nil || self.textview.text.characters.count>0 || isCameraScanning){
            self.buttonQr.isHidden = true;
            self.buttonCross.isHidden = false;
        }else{
            self.buttonQr.isHidden = false;
            self.buttonCross.isHidden = true;
        }
    }
    func checkStatusChange(){
        self.updateButtons()
        if(busyWorking || busyChangingStatus){return}
        
        //A: If no file is found, just look for text convertions
        if(self.fileDataPath == nil){
            if(canDecrypt()){
                //Esta en estado textCanDecrypt. Si el last status no es igual, toca animar
                if(lastStatus != .decryptText){
                    lastStatus = .decryptText
                    busyChangingStatus = true
                    self.fileimage.isHidden = false
                    //Anim
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 1.0, delay: 0.1, options: UIViewAnimationOptions.curveEaseOut, animations: {
                            self.buttonDecrypt.setTitle("Decrypt", for: .normal)
                            self.passOne.alpha = 0
                            self.fileimage.alpha = 1
                            self.textview.alpha = 0 //change text for image
                        }, completion: {_ in
                            print("Status cambiado a .decryptText")
                            self.busyChangingStatus = false
                            self.passOne.isHidden = true
                        })
                    }
                }
            }else{
                //Esta en estado textCanencrypt. Si el last status no es igual, toca animar
                if(lastStatus != .encryptText){
                    //Change button and status
                    lastStatus = .encryptText
                    busyChangingStatus = true
                    //Anim
                    DispatchQueue.main.async {
                        self.passOne.isHidden = false
                        UIView.animate(withDuration: 1.0, delay: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                            self.buttonDecrypt.setTitle("Encrypt", for: .normal)
                            self.passOne.alpha = 1
                            self.fileimage.alpha = 0
                            self.textview.alpha = 1 //fade imageicon and show text again
                        }, completion: {_ in
                            print("Status cambiado a .encryptText")
                            self.busyChangingStatus = false
                            self.fileimage.isHidden = true

                        })
                    }
                }
            }
        }else{
        //B: When a file is provided
            if(self.fileDataPath!.pathExtension == "safy"){
                if(lastStatus != .decryptFile){
                    lastStatus = .decryptFile
                    DispatchQueue.main.async {
                        self.fileimage.isHidden = false;
                        UIView.animate(withDuration: 0.5, delay: 0.02, options: UIViewAnimationOptions.curveEaseOut, animations: {
                            self.buttonDecrypt.setTitle("Decrypt file", for: .normal)
                            self.passOne.alpha = 0
                            self.fileimage.alpha = 1
                            self.textview.alpha = 0 //change text for image
                        }, completion: {_ in
                            print("Status cambiado a .decryptFile")
                            self.busyChangingStatus = false
                            self.passOne.isHidden = true
                            self.passTwo.text = ""
                            self.passOne.text = ""
                            //self.passTwo.becomeFirstResponder()
                        })
                    }
                }
            }else{
                if(lastStatus != .encryptFile){
                    lastStatus = .encryptFile
                    print("Status cambiado a .encryptFile")
                }
            }
            
        }
    }
    
    //MARK: Check if valid for decryption
    func canDecrypt() ->Bool{
        var valor:Bool = false;
        //A: If text
        if(self.fileDataPath == nil){
            if(textview.text?.range(of: CryptoHelper.armorHeader) != nil && textview.text?.range(of: CryptoHelper.armorFooter) != nil){
                //Can be decrypted
                valor = true;
            }
        }
        
        //B: If file, only can be decrypted if its a safy file
        if(lastStatus == .decryptFile){
            if(self.fileDataPath?.pathExtension == "safy"){
                valor = true
            }
        }
        
        return valor;
    }

    //MARK: Button Action
    @IBAction func textButtonDecryption(_ sender: Any) {
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
    
    //MARK: Textfield delegates
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        //Evito que puedas cambiar de linea y pierdo focus
        textField.resignFirstResponder()
        return false
    }
    
    //MARK: Keyboard: resize view
    func keyboardWillShow(notification: NSNotification) {
        keyboardShowOrHide(notification: notification)
    }
    
    func keyboardWillHide(notification: NSNotification) {
        keyboardShowOrHide(notification: notification)
    }
    
    private func keyboardShowOrHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo else {return}
        guard let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey]else { return }
        guard let curve = userInfo[UIKeyboardAnimationCurveUserInfoKey] else { return }
        guard let keyboardFrameEnd = userInfo[UIKeyboardFrameEndUserInfoKey] else { return }
        
        let curveOption = UIViewAnimationOptions(rawValue:  UInt( curve as! NSNumber))
        let keyboardFrameEndRectFromView = view.convert((keyboardFrameEnd as! CGRect) , from: nil)
        UIView.animate(withDuration: (duration as! TimeInterval) ,
                                   delay: 0,
                                   options: [curveOption, .beginFromCurrentState],
                                   animations: { () -> Void in
                                    //Este es el nuevo estado que quiero: y al llamarlo aqui, se hace animado.
                                    self.configureViewForKeyboard(view: self.view, keyboardorigin: keyboardFrameEndRectFromView.origin.y)
        }, completion: nil)
    }
    
    func configureViewForKeyboard(view: UIView, keyboardorigin: CGFloat){
        view.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: keyboardorigin)
    }
    
    //MARK: Share
    func manageShareType(){
        print("Manage type share!!")
        
        //if it doesn't have URL (like for example, if you scanned a bidi), just show bidi option
        var showFileOption = true;
        if(self.fileDataPath == nil){
            showFileOption = false;
        }
        
        //If possible, create QR. If not, just share
        if(self.textview.text.characters.count < 1 || self.textview.text.characters.count > 2300){
            //Only File
            if(showFileOption){
                self.shareAsSafyFile(urlpath: self.fileDataPath! as NSURL)
            }else{
                print("Has intentado compartir, pero no hay link ni posible bidi.")
            }
            return;
        }
        
        //Create Bidi removing possible cryptoheaders and footers
        let base64String = self.textview.text.replacingOccurrences(of: CryptoHelper.armorFooter, with: "").replacingOccurrences(of: CryptoHelper.armorHeader, with: "")

        
        //Show Alert Action sheet
        let settingsActionSheet: UIAlertController = UIAlertController(title:nil, message:nil, preferredStyle:UIAlertControllerStyle.actionSheet)
        settingsActionSheet.addAction(UIAlertAction(title:"Share as QR image", style:UIAlertActionStyle.default, handler:{ action in
            self.shareAsQR(base64string: base64String)
        }))
        if(showFileOption){
            settingsActionSheet.addAction(UIAlertAction(title:"Share as File", style:UIAlertActionStyle.default, handler:{ action in
                self.shareAsSafyFile(urlpath: self.fileDataPath! as NSURL)
            }))
        }
        settingsActionSheet.addAction(UIAlertAction(title:"Cancel", style:UIAlertActionStyle.cancel, handler:nil))
        present(settingsActionSheet, animated:true, completion:nil)
    }
    
    func shareAsSafyFile(urlpath: NSURL) {
        //var shareItems:Array = [img, messageStr]
        var shareItems:[NSURL] = []
        //shareItems.append(self.textview.text)
        shareItems.append(urlpath)
        if(shareItems.count == 0){
            showMessage(isError: true, text: "Can't share, no text", warnuser: true)
            return;
        }
        
        let activityViewController:UIActivityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        activityViewController.excludedActivityTypes = [UIActivityType.postToWeibo]
        
        //Before showing the controller, check if it's ipad or iphone
        if (UIDevice.current.userInterfaceIdiom == .pad){
            //It's an ipad, set popover location!
            activityViewController.popoverPresentationController?.sourceView = self.view
            //activityViewController.popoverPresentationController.sourceRect = self.frame;
            self.present(activityViewController, animated: true, completion: nil)
        }else{
            //It's an iPhone
            self.present(activityViewController, animated: true, completion: nil)
        }

    }
    func shareAsQR(base64string: String) {
        //var shareItems:Array = [img, messageStr]
        var shareItems:[UIImage] = []
        //shareItems.append(self.textview.text)
        let qrstring:String = "safyqr:/".appending(base64string)
        print("About to share string:\(qrstring)")
        let qrimage:UIImage = QRCode.generateImage(qrstring, showSafyFrame: false, avatarImage: UIImage(named: "fileprotected2"), avatarScale: 0.20)!
        shareItems.append(qrimage)
        print("Array of share \(shareItems)")
        if(shareItems.count == 0){
            showMessage(isError: true, text: "Can't share, no qr image", warnuser: true)
            return;
        }
        
        let activityViewController:UIActivityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        activityViewController.excludedActivityTypes = [UIActivityType.postToWeibo]
        
        //Before showing the controller, check if it's ipad or iphone
        if (UIDevice.current.userInterfaceIdiom == .pad){
            //It's an ipad, set popover location!
            activityViewController.popoverPresentationController?.sourceView = self.view
            //activityViewController.popoverPresentationController.sourceRect = self.frame;
            self.present(activityViewController, animated: true, completion: nil)
        }else{
            //It's an iPhone
            self.present(activityViewController, animated: true, completion: nil)
        }
        
    }
    
    //MARK Buttons
    
    @IBAction func scanQr(_ sender: Any) {
        qrview = UIView(frame: self.view.bounds)
        self.view.addSubview(qrview!)
        self.view.bringSubview(toFront: qrview!)
        isCameraScanning = true;
        qrscanner.prepareScan(qrview!) { (stringValue) -> () in
            if(stringValue.range(of: "safyqr:/") == nil){
                self.showMessage(isError: true, text: "Error: That's not a Safy QR encrypted code", warnuser: true);
            }else{
                //Create a string removing safyqr:/ and adding header+footer
                let stringToShow = CryptoHelper.armorHeader.appending(stringValue.replacingOccurrences(of: "safyqr:/", with: "")).appending(CryptoHelper.armorFooter)
                //Add that string to text so it can be decrypted
                self.textview.text = stringToShow
                self.textview.alpha = 0; //no quiero que se vea
                self.fileDataPath = nil; //no quiero que sobreescriba y se lie varios archivos diferentes
            }
            self.qrscanner.stopScan()
            self.qrview?.removeFromSuperview()
            self.isCameraScanning = false;
            self.qrview = nil;
        }
        self.view.bringSubview(toFront: self.buttonCross)
        qrscanner.scanFrame = qrview!.bounds
        qrscanner.startScan()
    
    }

    @IBAction func crossPressed(_ sender: Any) {
        if(isCameraScanning){
            self.qrscanner.stopScan()
            self.qrview?.removeFromSuperview()
            isCameraScanning = false;
            self.qrview = nil;
        }
        //Cleans the actual file
        self.fileDataPath = nil;
        self.textview.text = ""
        self.textview.becomeFirstResponder()
    }
    
}

