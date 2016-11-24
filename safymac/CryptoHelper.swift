//
//  CryptoHelper.swift
//  safymac
//
//  Created by Sergio Abril Herrero on 23/11/16.
//  Copyright © 2016 Sergio Abril Herrero. All rights reserved.
//

import Foundation
import CryptoSwift



// MARK: Crypto class
class CryptoHelper{
    static var armorHeader:String!{
        return String("---Safy: Begin of encryption---\n")
    }
    static var armorFooter:String!{
        return String("\n---End of encryption---")
    }
    static func deriveKeyFromPassword(pass:String, vectorsalt: Array<UInt8>) -> Array<UInt8>{
        var value: [UInt8] = []
      
        do{
            //Preparo la pass y el salt en Bytes. El salt ahora es el mismo que el IV, que es random.
            let password: Array<UInt8> = pass.utf8.map {$0}
            let salt: Array<UInt8> = vectorsalt;//vectorsalt.utf8.map {$0}
            //Derivo en sha256 para obtener 32bytes
            //value = try PKCS5.PBKDF2(password: password, salt: salt, iterations: 4096, variant: .sha256).calculate()
            value = try PKCS5.PBKDF2(password: password, salt: salt, iterations: 20000, variant: .sha256).calculate()

        }catch{
            print("Error hasing pashword");
        }
        return value;
    }
    
    static func SeparateIvFromCipherString(cipher:String) -> (cipher:String, iv:String){
        //Try to read the iv string Hex again:
        let ivStartIndex = cipher.index(cipher.startIndex, offsetBy: 0)
        let ivEndIndex = cipher.index(cipher.startIndex, offsetBy: 31)
        
        //Get IV
        let rangeIV = ivStartIndex...ivEndIndex
        let capturedIV:String = cipher[rangeIV]
        //print("Captured UV \(capturedIV)")
        
        //Get Real Cipher
        let cipherStartIndex = cipher.index(cipher.startIndex, offsetBy:32)
        let cipherEndIndex = cipher.index(cipher.endIndex, offsetBy:-1)
        let restCipher:String = cipher[cipherStartIndex...cipherEndIndex]
        //print("Captured cipher \(restCipher)")
        return (cipher:restCipher, iv: capturedIV)
    }
    
    static func decryptAES256fromBytes(databytes: Array<UInt8>, password:String) -> Array<UInt8>{
        //Create pass and load IV + chipher
        let separator = self.SeparateIvFromCipherString(cipher: databytes.toHexString())
        let vector = separator.iv
        let realcipher = separator.cipher
        //Decrypt:
        let input: Array<UInt8> = Array<UInt8>(hex: realcipher)
        let iv: Array<UInt8> = Array<UInt8>(hex: vector)
        let key: Array<UInt8> = deriveKeyFromPassword(pass: password, vectorsalt: iv)
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
        let key: Array<UInt8> = deriveKeyFromPassword(pass: password, vectorsalt: iv)

        //print("IV es \(iv.toHexString())")
        do {
            var encrypted = try AES(key: key, iv: iv, blockMode: .CBC, padding: PKCS7()).encrypt(input)
            //Store Hex string of the encrypted data
            let hexString = (iv.toHexString()).appending(encrypted.toHexString())
            //Add IV to the string at the end
            // hexString = hexString.appending(iv.toHexString())
            //Save encrypted again
            encrypted = Array<UInt8>(hex: hexString)
            //Return
            return encrypted
            
        } catch {
            print(error)
        }
        return []
    }

}
