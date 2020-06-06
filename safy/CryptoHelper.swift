//
//  CryptoHelper.swift
//  safymac
//
//  Created by Sergio Abril Herrero on 23/11/16.
//  Copyright © 2016 Sergio Abril Herrero. All rights reserved.
//

import Foundation
import CryptoSwift


class CryptoHelper{
    //MARK: Enums and structs
    //Decryption status
    public enum decryptionresult{
        case ok
        case error
    }
    
    //File format struct
    public struct fileFormatPack {
        let fileformat:fileFormat
        let kindOfFileIndex:UInt8
    }
    
    //File format possibilities
    public enum fileFormat:String{
        case plaintext = ""
        case txt = "txt"
        case jpg = "jpg"
        case jpeg = "jpeg"
        case png = "png"
        case mp4 = "mp4"
        case mov = "mov"
        
        static let allValues = [plaintext,txt,jpg,jpeg,png,mp4,mov]
    }
    
    //MARK: Headers for ascii text
    static var armorHeader:String!{
        return String("----Safy----\n")
    }
    static var armorFooter:String!{
        return String("\n----/Safy----")
    }
    
    //MARK: file format methods
    static func getFileFormatFromPath(path:URL?) -> fileFormat
    {
        //By default, just plain text
        var thefileformat:fileFormat = .plaintext
        let fileextension:String? = path?.pathExtension
        if(fileextension == nil){return thefileformat}
        for format in fileFormat.allValues{
            print("getfilefrom...\(format.rawValue) and \(fileextension!) ")
            if(format.rawValue == fileextension!){
                thefileformat = CryptoHelper.fileFormat(rawValue: format.rawValue)!
                break
            }
        }
        return thefileformat
    }
    //Get byte value from a given fileformat
    static func getByteFlagForFileFormat(fileformat:fileFormat) -> UInt8{
        let index = fileFormat.allValues.index(of: fileformat)!
        let byteflag:UInt8 = UInt8(exactly: index)!
        return byteflag
    }
    //Get fileformat from given UInt8 value given
    static func getFileFormatForByteFlag(bytenumber:UInt8) -> fileFormat{
        for (index,fileform) in fileFormat.allValues.enumerated(){
            if(index == Int(bytenumber)){
                return fileform
            }
        }
        return .plaintext
    }
    
    //MARK: Previous operations
    //Derive password from string/iterations/vectorsalt
    static func deriveKeyFromPassword(pass:String, vectorsalt: Array<UInt8>, iterationFactor: Int) -> (key:Array<UInt8>, iv:Array<UInt8>, iv2:Array<UInt8>){
        var key: [UInt8] = []
        var iv: [UInt8] = []
        var iv2: [UInt8] = []
        do{
            //Prepare string to bytes, ans same for salt if needed.
            let password: Array<UInt8> = pass.utf8.map {$0}
            let salt: Array<UInt8> = vectorsalt;
            //Derive using sha512 to get a 64byte string. Then split it.
            let value: [UInt8] = try PKCS5.PBKDF2(password: password, salt: salt, iterations: 25000 * iterationFactor, variant: .sha512).calculate()
            print("derived key has \(value.count)")
            //32 bytes as key for AES256
            key = Array(value[0..<32])
            //iv, 16bytes
            iv = Array(value[32..<48])
            //Another iv of 16bytes. Will be used for HMAC.
            iv2 = Array(value[48..<value.count])

        }catch{
            print("Error hasing password");
        }
        return (key:key, iv:iv, iv2:iv2)
    }
    
    //Separate Headers and Encrypted data (using bytes)
    static func separateHeadersFromBytes(encryptedbytes:[UInt8]) -> (fileformat:fileFormat, cipher:Array<UInt8>, salt:Array<UInt8>, iterations: Int){
        
        //First byte is File Format. 2 Hex Char.
        let ffByte:UInt8 = encryptedbytes[0]
        let fileform = self.getFileFormatForByteFlag(bytenumber: ffByte)
        //print("Leyendo fake fileflag: \(ffByte) - \(fileform)");
        
        //Try to read the salt. Next 16Bytes/Octets (32HexChar)
        let saltBytes = encryptedbytes[1..<17] //Subarray from [1] to [16] inclusive. 16bytes.
        //print("Captured UV \(ivBytes)")
        
        //Get iteration factor: 1 byte (0-255) : 2 characteres of an HexString
        let iterByte = encryptedbytes[17]
        let capturedIterator = Int(iterByte); //By default 1 * 16384
        //print("Iteration count: \(capturedIterator)")
        
        //Get Real Cipher: the rest of bytes
        let ciphertext = encryptedbytes[18..<encryptedbytes.count] //from 18(inclusive) to the index number of elements(exclusive). An alternative is [18...encryptedbytes.count-1]
        //print("Captured cipher \(restCipher)")
        
        //Return
        return (fileformat: fileform, cipher:Array(ciphertext), salt: Array(saltBytes), iterations: capturedIterator)
    }

    //MARK: HMAC Hash
    //Has Hmac from bytes
    static func getHMACfromBytes(input:Array<UInt8>, salt:Array<UInt8>) -> Array<UInt8>{
        var hmacsig:[UInt8] = [UInt8]()
        //print("HMAC... from input \(input) and salt \(salt)");
        do{
            hmacsig = try HMAC(key: salt, variant: .sha256).authenticate(input)
            //Add hmac signature at the end of the hole
        }catch{
            print("Error hasing HMAC")
            return []
        }
        //print("HMAC is \(hmacsig). count \(hmacsig.count)");
        return hmacsig;
    }
    
    //Separate plaintext and hmac hash from a decrypted array, and check integrity/password
    static func separateAndCheckHMAC(input:Array<UInt8>, salt:Array<UInt8>) -> (isPassOk:Bool, decrypted:Array<UInt8>){
        //Separate string
        let plaintext = Array(input[0..<input.count-32])
        let hmacsig = Array(input[input.count-32..<input.count])
        //print("plaintext and hmac separated: \(plaintext) - - - \(hmacsig)");
        //Create HMAC from plaintext and compare
        let hmacsignew = getHMACfromBytes(input: plaintext, salt: salt);
        //print("hmac sig from plaintext:\(hmacsignew)");
        //Compare and return status
        var status = false;
        if(hmacsignew == hmacsig){
            status = true;
        }
        return(isPassOk:status, decrypted:plaintext)
    }
    
    //MARK: Encryption functions
    //Decrypt
    static func decryptAES256fromBytes(databytes: Array<UInt8>, password:String) -> (plaintext: Array<UInt8>, status: decryptionresult, fileformat:fileFormat?){
        //Separate parts
        let separator = self.separateHeadersFromBytes(encryptedbytes: databytes);
        let input = separator.cipher
        let salt = separator.salt
        let iterations = separator.iterations
        let fileformat = separator.fileformat
        
        //Derive given password with given salt, and get key/iv/hmacsalt
        let derived = deriveKeyFromPassword(pass: password, vectorsalt: salt, iterationFactor: iterations)
        let key = derived.key
        let iv = derived.iv

        //Decrypt:
        do {
            let decrypted = try AES(key: key, iv: iv, blockMode: .CBC, padding: PKCS7()).decrypt(input)
            //print("decrypted \(decrypted)");
            if(decrypted.count>0){
                //Separate text from HMAC and test.
                var newArrayOfBytes = decrypted;
                let hmacCalculations = separateAndCheckHMAC(input: newArrayOfBytes, salt: derived.iv2);
                let isPassOk = hmacCalculations.isPassOk;
                newArrayOfBytes = hmacCalculations.decrypted;
                if(isPassOk){
                    return (plaintext: newArrayOfBytes, status: .ok, fileformat:fileformat)
                }else{
                    return (plaintext: [], status: .error, fileformat: nil) //HMAC failed. data corrupted or wrong password.
                }
            }
        } catch {
            print(error)
        }
        return (plaintext: [], status: .error, fileformat: nil)
    }
    
    //Encrypt
    static func encryptAES256fromBytes(databytes: Array<UInt8>, password: String, urlfile: URL? = nil) -> Array<UInt8>{
        //Copy input plaintext to an array
        var input: Array<UInt8> = databytes
        
        //Create the flag for file format
        var fileformatFlag:Array<UInt8> = [self.getByteFlagForFileFormat(fileformat: self.getFileFormatFromPath(path: urlfile))]

        //Create flag for iterations count (for the derived key)
        let iterations = 5
        let iterBytes:[UInt8] = [UInt8(iterations)]
        
        //Salt for the key
        let salt: Array<UInt8> = AES.randomIV(AES.blockSize)
        
        //Derive key, iv and salt for hMAC
        let derived = deriveKeyFromPassword(pass: password, vectorsalt: salt, iterationFactor: iterations)
        let key = derived.key
        let iv = derived.iv
        let hmacsalt = derived.iv2
        
        //Hash HMAC. Hash input and add to the end. *Before encryption*. It's 32Bytes. Use iv2 as salt.
        let hmacsig = getHMACfromBytes(input: input, salt: hmacsalt);
        
        //Add HMAC at the end of the plaintext before encrypting
        input.append(contentsOf: hmacsig)
        
        //Encrypt
        do {
            //1. Encrypt. Get cipher text in bytes
            let ciphertext = try AES(key: key, iv: iv, blockMode: .CBC, padding: PKCS7()).encrypt(input)
            //2. Appending headers (as bytes) to the first array (which happens to be fileformatFlag)
            fileformatFlag.append(contentsOf: salt)
            fileformatFlag.append(contentsOf: iterBytes)
            fileformatFlag.append(contentsOf: ciphertext)
            return fileformatFlag

        } catch {
            print(error)
        }
        return []
    }

}
