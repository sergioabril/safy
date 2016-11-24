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
    //MARK: Headers and footers of armored files
    static var armorHeader:String!{
        return String("----Safy----\n")
    }
    static var armorFooter:String!{
        return String("\n----End of encryption----")
    }
    
    //MARK: Derive password
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
    
    //MARK: Separate Headers and Encrypted data
    static func SeparateIvFromCipherString(cipher:String) -> (cipher:String, iv:String, iterations: Int){
        //Try to read the iv string Hex again:
        let ivStartIndex = cipher.index(cipher.startIndex, offsetBy: 0)
        let ivEndIndex = cipher.index(cipher.startIndex, offsetBy: 31)
        
        //Get IV
        let rangeIV = ivStartIndex...ivEndIndex
        let capturedIV:String = cipher[rangeIV]
        //print("Captured UV \(capturedIV)")
        
        //Get iteration factor: 1 byte (0-255) : 2 characteres of an HexString
        let iterStartIndex = cipher.index(cipher.startIndex, offsetBy: 32)
        let iterEndIndex = cipher.index(cipher.startIndex, offsetBy: 33)
        let rangeIter = iterStartIndex...iterEndIndex
        let capturedIteratorString = cipher[rangeIter]
        var capturedIterator = 1; //By default 1 * 4096
        if let value = UInt8(capturedIteratorString, radix: 16) {
            capturedIterator = Int(value)
        }
        
        //Get Real Cipher
        let cipherStartIndex = cipher.index(cipher.startIndex, offsetBy:34)
        let cipherEndIndex = cipher.index(cipher.endIndex, offsetBy:-1)
        let restCipher:String = cipher[cipherStartIndex...cipherEndIndex]
        //print("Captured cipher \(restCipher)")
        return (cipher:restCipher, iv: capturedIV, iterations: capturedIterator)
    }
    
    
    //MARK: Encryption functions
    static func decryptAES256fromBytes(databytes: Array<UInt8>, password:String) -> Array<UInt8>{
        //Create pass and load IV + chipher
        let separator = self.SeparateIvFromCipherString(cipher: databytes.toHexString())
        let vector = separator.iv
        let realcipher = separator.cipher
        let iterations = separator.iterations
        //Decrypt:
        let input: Array<UInt8> = Array<UInt8>(hex: realcipher)
        let iv: Array<UInt8> = Array<UInt8>(hex: vector)
        let key: Array<UInt8> = deriveKeyFromPassword(pass: password, vectorsalt: iv, iterationFactor: iterations)
        do {
            let decrypted = try AES(key: key, iv: iv, blockMode: .CBC, padding: PKCS7()).decrypt(input)
            return decrypted
        } catch {
            print(error)
        }
        return []
    }
    
    static func encryptAES256fromBytes(databytes: Array<UInt8>, password: String) -> Array<UInt8>{
        let input: Array<UInt8> = databytes
        
        let iv: Array<UInt8> = AES.randomIV(AES.blockSize)
        
        let iterations = 10
        let iterBytes:[UInt8] = [UInt8(iterations)]
        let iterHex = iterBytes.toHexString()
        
        let key: Array<UInt8> = deriveKeyFromPassword(pass: password, vectorsalt: iv, iterationFactor: iterations)
        //print("IV es \(iv.toHexString())")
        do {
            //Encrypt
            var encrypted = try AES(key: key, iv: iv, blockMode: .CBC, padding: PKCS7()).encrypt(input)
            //Store Hex string of the encrypted data:
            let hexString = iv.toHexString().appending(iterHex).appending(encrypted.toHexString())
            //Test - Get back Binary data from hex string:
            encrypted = Array<UInt8>(hex: hexString)
            //Return
            return encrypted
        } catch {
            print(error)
        }
        return []
    }

}
