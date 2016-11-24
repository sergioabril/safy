//
//  ViewController.swift
//  safyios
//
//  Created by Sergio Abril Herrero on 23/11/16.
//  Copyright © 2016 Sergio Abril Herrero. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITextFieldDelegate {

    enum currentLayoutStatus {
        case none
        case encryptText
        case decryptText
    }
    
    @IBOutlet weak var passOne: UITextField!
    @IBOutlet weak var passTwo: UITextField!
    
    @IBOutlet weak var textview: UITextView!
    @IBOutlet weak var buttonDecrypt: UIButton!
    
    var busyWorking:Bool = false
    var busyChangingStatus:Bool = false
    var statusChecker:Timer = Timer()
    var lastStatus:currentLayoutStatus = currentLayoutStatus.none
    
    //ProgressBall
    var loader:SALoaderOvalBlur?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.passOne.delegate = self
        self.passTwo.delegate = self
       
        //INstantiate loader
        self.loader = SALoaderOvalBlur(onView:self.view, radius: 20, blurBackground: true)
    
    }
    override func viewWillAppear(_ animated: Bool) {
        //Add notifications for keyboard
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: .UIKeyboardWillHide, object: nil)
        
        //Reset timer to check the layout 
        statusChecker.invalidate()
        statusChecker = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(self.checkStatusChange), userInfo: nil, repeats: true)
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
            
            let bytesEncryptados = CryptoHelper.encryptAES256fromBytes(databytes: bytesToEncrypt, password: self.passOne.text!)
            let cadenaFinal = CryptoHelper.armorHeader.appending(bytesEncryptados.toBase64()!).appending(CryptoHelper.armorFooter)
            
            DispatchQueue.main.async {
                //Set string to textview
                //print("Finished: \(cadenaFinal)")
                self.textview.text = cadenaFinal
                self.unmarkBusy()
                //Share
                self.shareEncryptedResult()
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
        
        
        //Avoid empty texts
        if(textview.text == nil){
            showMessage(isError: true, text: "No hay nada que desencriptar", warnuser: true)
            unmarkBusy()
            return;
        }
        
        //Obtengo texto y quito headers y footers. Esa es mi base64
        var newBase64:String! = textview.text!.replacingOccurrences(of: CryptoHelper.armorHeader, with: "")
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
            let decryptedBytes:Array<UInt8> = CryptoHelper.decryptAES256fromBytes(databytes: bytesToDecrypt, password: self.passTwo.text!)
            
            //Ahora mapeo los bytes a caracteres gracias a la extension: "extension UInt8 { var character: Character {... " que he puesto justo despues
            //let characters = decryptedBytes.map { $0.character }
            //let newstring = String(characters)
            let newstring = decryptedBytes.utf8string //custom extension
            DispatchQueue.main.async {
                //Set string to textview
                self.textview.text = newstring;
                //Not work anymore
                self.unmarkBusy()
                //Clean passwords and lose focus
                self.passOne.text = ""
                self.passTwo.text = ""
            }
        }
        
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
    func checkStatusChange(){
        if(busyWorking || busyChangingStatus){return}
        
        if(canDecrypt()){
            //Esta en estado textCanDecrypt. Si el last status no es igual, toca animar
            if(lastStatus != .decryptText){
                lastStatus = .decryptText
                busyChangingStatus = true
                //Anim
                UIView.animate(withDuration: 1.0, delay: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                    self.buttonDecrypt.setTitle("Decrypt", for: .normal)
                    self.passOne.alpha = 0
                }, completion: {_ in
                    print("Status cambiado a .decryptText")
                    self.busyChangingStatus = false
                    self.passOne.isHidden = true
                })
            }
        }else{
            //Esta en estado textCanencrypt. Si el last status no es igual, toca animar
            if(lastStatus != .encryptText){
                //Change button and status
                lastStatus = .encryptText
                busyChangingStatus = true
                //Anim
                self.passOne.isHidden = false
                UIView.animate(withDuration: 1.0, delay: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                    self.buttonDecrypt.setTitle("Encrypt", for: .normal)
                    self.passOne.alpha = 1
                }, completion: {_ in
                    print("Status cambiado a .encryptText")
                    self.busyChangingStatus = false
                    
                })
            }
        }
    }
    
    //MARK: Check if valid for decryption
    func canDecrypt() ->Bool{
        var valor:Bool = false;
        if(textview.text?.range(of: CryptoHelper.armorHeader) != nil && textview.text?.range(of: CryptoHelper.armorFooter) != nil){
            //Can be decrypted
            valor = true;
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
        print("keyboard show")
        keyboardShowOrHide(notification: notification)
    }
    
    func keyboardWillHide(notification: NSNotification) {
        print("keyboard hide")
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
    func shareEncryptedResult() {
        //var shareItems:Array = [img, messageStr]
        var shareItems:[String] = []
        shareItems.append(self.textview.text)
        
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

}

