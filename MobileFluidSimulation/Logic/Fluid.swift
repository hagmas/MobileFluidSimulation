//
//  Fluid.swift
//  MobileFluidSimulation
//
//  Created by Haga Masaki on 26/09/2017.
//  Copyright © 2017 Haga Masaki. All rights reserved.
//

import Foundation
import MetalKit
import Accelerate

enum SurfaceFloatFormat {
    case float, half
}

struct Fluid {
    static let floatFormat: SurfaceFloatFormat = .half
    static let densityComponents: Int = 4
    
    let width: Int
    let height: Int
    
    let velocity: Slab
    let pressure: Slab
    let density: Slab
    
    let divergence: MTLTexture
    
    init?(device: MTLDevice, width: Int, height: Int) {
        let format = Fluid.floatFormat
        guard let velocity = device.makeSlab(width: width, height: height, format: format, numberOfComponents: 2),
            let pressure = device.makeSlab(width: width, height: height, format: format, numberOfComponents: 1),
            let density = device.makeSlab(width: width, height: height, format: format, numberOfComponents: Fluid.densityComponents),
            let divergence = device.makeSurface(width: width, height: height, format: format, numberOfComponents: 3) else {
                return nil
        }
        
        self.width = width
        self.height = height
        
        self.velocity = velocity
        self.pressure = pressure
        self.density = density
        self.divergence = divergence
        
        createVelocityInitialState()
        createPressureInitialState()
        createDensityInitialState()
    }
    
    private func createVelocityInitialState() {
        var initialGrid: [Float] = Array(repeating: 0, count: width * height * 2)
        for i in 0..<height {
            for j in 0..<width {
                let radianX = 2 * Float.pi * Float(j % 100) / 100
                let radianY = 2 * Float.pi * Float(i % 100) / 100
                initialGrid[j*2 + i*width*2] = sin(radianX)
                initialGrid[j*2 + i*width*2 + 1] = cos(radianY)
            }
        }
        
        switch type(of: self).floatFormat {
        case .float:
            let region = MTLRegionMake2D(0, 0, width, height)
            let rowBytes = MemoryLayout<Float>.size * width * 2
            velocity.source.replace(region: region,
                                    mipmapLevel: 0,
                                    withBytes: &initialGrid,
                                    bytesPerRow: rowBytes)
        case .half:
            var outputGrid: [UInt16] = Array(repeating: 0, count: width * height * 2)
            let sourceRowBytes = MemoryLayout<Float>.size * width * 2
            let destRowBytes = MemoryLayout<UInt16>.size * width * 2
            var source = vImage_Buffer(data: &initialGrid, height: UInt(height), width: UInt(width) * 2, rowBytes: sourceRowBytes)
            var dest = vImage_Buffer(data: &outputGrid, height: UInt(height), width: UInt(width) * 2, rowBytes: destRowBytes)
            vImageConvert_PlanarFtoPlanar16F(&source, &dest, 0)
            
            let region = MTLRegionMake2D(0, 0, width, height)
            velocity.source.replace(region: region,
                                    mipmapLevel: 0,
                                    withBytes: &outputGrid,
                                    bytesPerRow: destRowBytes)
        }
    }
    
    private func createPressureInitialState() {
        switch type(of: self).floatFormat {
        case .float:
            var initialGrid: [Float] = Array(repeating: 0, count: width * height)
            let region = MTLRegionMake2D(0, 0, width, height)
            let rowBytes = MemoryLayout<Float>.size * width
            pressure.source.replace(region: region,
                                    mipmapLevel: 0,
                                    withBytes: &initialGrid,
                                    bytesPerRow: rowBytes)
        case .half:
            var initialGrid: [UInt16] = Array(repeating: 0, count: width * height)
            let region = MTLRegionMake2D(0, 0, width, height)
            let rowBytes = MemoryLayout<UInt16>.size * width
            pressure.source.replace(region: region,
                                    mipmapLevel: 0,
                                    withBytes: &initialGrid,
                                    bytesPerRow: rowBytes)
        }
    }
    
    private func createDensityInitialState() {
        var initialGrid: [Float] = Array(repeating: 0, count: width * height * Fluid.densityComponents)
        for i in 0..<height {
            for j in 0..<width {
                let x = (j / 100) % 4
                let y = (i / 100) % 4
                
                switch (x+y) % 4 {
                case 1:
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents] = 210/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 1] = 71/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 2] = 116/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 3] = 1.0
                case 2:
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents] = 33/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 1] = 62/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 2] = 145/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 3] = 1.0
                case 3:
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents] = 221/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 1] = 88/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 2] = 72/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 3] = 1.0
                default:
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents] = 251/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 1] = 246/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 2] = 242/255
                    initialGrid[j*Fluid.densityComponents + i*width*Fluid.densityComponents + 3] = 1.0
                }
            }
        }
        
        switch type(of: self).floatFormat {
        case .float:
            let region = MTLRegionMake2D(0, 0, width, height)
            density.source.replace(region: region,
                                   mipmapLevel: 0,
                                   withBytes: &initialGrid,
                                   bytesPerRow: MemoryLayout<Float>.size * width * Fluid.densityComponents)
        case .half:
            var outputGrid: [UInt16] = Array(repeating: 0, count: width * height * Fluid.densityComponents)
            let sourceRowBytes = MemoryLayout<Float>.size * width * Fluid.densityComponents
            let destRowBytes = MemoryLayout<UInt16>.size * width * Fluid.densityComponents
            var source = vImage_Buffer(data: &initialGrid, height: UInt(height), width: UInt(width * Fluid.densityComponents), rowBytes: sourceRowBytes)
            var dest = vImage_Buffer(data: &outputGrid, height: UInt(height), width: UInt(width * Fluid.densityComponents), rowBytes: destRowBytes)
            vImageConvert_PlanarFtoPlanar16F(&source, &dest, 0)
            
            let region = MTLRegionMake2D(0, 0, width, height)
            density.source.replace(region: region,
                                   mipmapLevel: 0,
                                   withBytes: &outputGrid,
                                   bytesPerRow: destRowBytes)
        }
    }
}
