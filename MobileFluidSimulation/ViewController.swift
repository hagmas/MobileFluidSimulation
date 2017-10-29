//
//  ViewController.swift
//  MobileFluidSimulation
//
//  Created by Haga Masaki on 19/10/2017.
//  Copyright © 2017 Haga Masaki. All rights reserved.
//

import UIKit
import MetalKit

class ViewController: UIViewController {

    var renderer: Renderer?
    @IBOutlet weak var metalView: MTKView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        metalView.framebufferOnly = false
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        metalView.drawableSize = metalView.frame.size
        metalView.isMultipleTouchEnabled = true
        
        renderer = Renderer(with: metalView)
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        gestureRecognizer.numberOfTapsRequired = 2
        metalView.addGestureRecognizer(gestureRecognizer)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var touchEvents = [Renderer.TouchEvent]()
        for touch in touches {
            let location = touch.location(in: metalView)
            let previousLocation = touch.previousLocation(in: metalView)
            let deltaX = location.x - previousLocation.x
            let deltaY = location.y - previousLocation.y
            
            if (0.0..<metalView.bounds.width).contains(location.x) && (0.0..<metalView.bounds.height).contains(location.y) {
                let touchEvent = Renderer.TouchEvent(point: location, delta: CGPoint(x: deltaX, y: deltaY))
                touchEvents.append(touchEvent)
            }
        }
        
        guard touchEvents.count > 0 else {
            return
        }
        
        renderer?.touchEvents = touchEvents
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        renderer?.touchEvents = nil
    }
    
    @objc func doubleTapped() {
        renderer?.reset()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

