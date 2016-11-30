//
//  CryptoHelper.swift
//  safymac
//
//  Created by Sergio Abril Herrero on 23/11/16.
//  Copyright © 2016 Sergio Abril Herrero. All rights reserved.
//

import Foundation
import CryptoSwift


struct EncryptedPackage {
    var filepath:URL?
    var base64data:String?
    var rawcipherstring:String?
    var filetype:CryptoHelper.fileFormat!
}

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
            if(format.rawValue == fileextension){
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
    
    //Derive password
    static func deriveKeyFromPassword(pass:String, vectorsalt: Array<UInt8>, iterationFactor: Int) -> Array<UInt8>{
        var value: [UInt8] = []
        do{
            //Preparo la pass y el salt en Bytes. El salt ahora es el mismo que el IV, que es random.
            let password: Array<UInt8> = pass.utf8.map {$0}
            let salt: Array<UInt8> = vectorsalt;//vectorsalt.utf8.map {$0}
            //Derivo en sha256 para obtener 32bytes
            value = try PKCS5.PBKDF2(password: password, salt: salt, iterations: 4096 * iterationFactor, variant: .sha256).calculate()
        }catch{
            print("Error hasing password");
        }
        return value;
    }
    
    //Separate Headers and Encrypted data
    static func separateHeadersFromChipherString(cipher:String) -> (fileformat:fileFormat, cipher:String, iv:String, iterations: Int){
        
        //First byte is File Format. 2 Hex Char.
        let fformStartIndex = cipher.index(cipher.startIndex, offsetBy: 0)
        let fformEndIndex = cipher.index(cipher.startIndex, offsetBy: 1)
        let rangeFF = fformStartIndex...fformEndIndex
        let ffHexString:String = cipher[rangeFF]
        let ffBytes:Array<UInt8> = Array<UInt8>(hex: ffHexString)
        let fileform = self.getFileFormatForByteFlag(bytenumber: ffBytes[0])
        //print("Leyendo fake fileflag: \(ffHexString) - \(ffBytes) - \(fileform)");
        
        //Try to read the iv. Next 16Bytes/Octets (32HexChar)
        let ivStartIndex = cipher.index(cipher.startIndex, offsetBy: 2)
        let ivEndIndex = cipher.index(cipher.startIndex, offsetBy: 33)
        let rangeIV = ivStartIndex...ivEndIndex
        let capturedIV:String = cipher[rangeIV]
        //print("Captured UV \(capturedIV)")
        
        //Get iteration factor: 1 byte (0-255) : 2 characteres of an HexString
        let iterStartIndex = cipher.index(cipher.startIndex, offsetBy: 34)
        let iterEndIndex = cipher.index(cipher.startIndex, offsetBy: 35)
        let rangeIter = iterStartIndex...iterEndIndex
        let capturedIteratorString = cipher[rangeIter]
        var capturedIterator = 1; //By default 1 * 4096
        if let value = UInt8(capturedIteratorString, radix: 16) {
            capturedIterator = Int(value)
        }
        //Get Real Cipher: the rest
        let cipherStartIndex = cipher.index(cipher.startIndex, offsetBy:36)
        let cipherEndIndex = cipher.index(cipher.endIndex, offsetBy:-1)
        let restCipher:String = cipher[cipherStartIndex...cipherEndIndex]
        //print("Captured cipher \(restCipher)")

        //Return
        return (fileformat: fileform, cipher:restCipher, iv: capturedIV, iterations: capturedIterator)
    }
    

    
    //MARK: Encryption functions
    //Decrypt
    static func decryptAES256fromBytes(databytes: Array<UInt8>, password:String) -> (plaintext: Array<UInt8>, status: decryptionresult, fileformat:fileFormat?){
        //Load needed values from data
        let separator = self.separateHeadersFromChipherString(cipher: databytes.toHexString())
        let fileformat = separator.fileformat
        let vector = separator.iv
        let iterations = separator.iterations
        let realcipher = separator.cipher
        //Prepare byte values
        let input: Array<UInt8> = Array<UInt8>(hex: realcipher)
        let iv: Array<UInt8> = Array<UInt8>(hex: vector)
        let key: Array<UInt8> = deriveKeyFromPassword(pass: password, vectorsalt: iv, iterationFactor: iterations)

        //Decrypt:
        do {
            let decrypted = try AES(key: key, iv: iv, blockMode: .CBC, padding: PKCS7()).decrypt(input)
            if(decrypted.count>0){
                //Test if password was right. First 4 bytes have to be 80. If not, password was wrong or data corrupted...
                if(decrypted[0] == 80 && decrypted[1] == 80 && decrypted[2] == 80 && decrypted[3] == 80){
                        var newArrayOfBytes = decrypted;
                        for _ in 0...3 { newArrayOfBytes.remove(at: 0)} //remove 4 bytes
                    return (plaintext: newArrayOfBytes, status: .ok, fileformat:fileformat)
                }
            }
        } catch {
            print(error)
        }
        return (plaintext: [], status: .error, fileformat: nil)
    }
    //Encrypt
    static func encryptAES256fromBytes(databytes: Array<UInt8>, password: String, urlfile: URL? = nil) -> Array<UInt8>{
        var input: Array<UInt8> = databytes
        for _ in 0...3 { input.insert(80, at: 0)} //add 4 0x80 bytes
        
        let iv: Array<UInt8> = AES.randomIV(AES.blockSize)
        
        let iterations = 10
        let iterBytes:[UInt8] = [UInt8(iterations)]
        let iterHex = iterBytes.toHexString()
        
        let fileformatFlag:Array<UInt8> = [self.getByteFlagForFileFormat(fileformat: self.getFileFormatFromPath(path: urlfile))]
        
        let key: Array<UInt8> = deriveKeyFromPassword(pass: password, vectorsalt: iv, iterationFactor: iterations)
        //print("IV es \(iv.toHexString())")
        do {
            //1. Encrypt. Get cipher text in bytes
            var ciphertext = try AES(key: key, iv: iv, blockMode: .CBC, padding: PKCS7()).encrypt(input)
            //print("hmacSignature: \(hmacSignature.count) - \(hmacSignature.toHexString())");
            //2. Create a long hexadecimal string appending all the parts /header, body, etc
            let hexString = fileformatFlag.toHexString().appending(iv.toHexString()).appending(iterHex).appending(ciphertext.toHexString())
            //Test - Get back Binary data from hex string:
            ciphertext = Array<UInt8>(hex: hexString)
            //Return
            return ciphertext
        } catch {
            print(error)
        }
        return []
    }

}
