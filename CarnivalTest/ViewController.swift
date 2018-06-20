//
//  ViewController.swift
//  CarnivalTest
//
//  Created by Aaron Gray on 6/20/18.
//  Copyright © 2018 Aaron Gray. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var selectedAnchor: ARAnchor? = nil;
    var anchors: [ARAnchor] = [ARAnchor]()
    
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~APP STATE CONTROL~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action:#selector(handleTap(rec:)))
        
        sceneView.addGestureRecognizer(tapRecognizer)

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~AR ANCHORS~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        
        guard let planeAnchor = anchor as? ARPlaneAnchor else {return}
        
//        Add spherical marker
        let marker = SCNSphere(radius: 0.01)
        let markerNode = SCNNode(geometry: marker)
        markerNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        markerNode.opacity = 0.8
        
//        Add planar extent indicator
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        planeNode.opacity = 0.25
        planeNode.eulerAngles.x = -.pi / 2
        
//        Add visual indicator nodes to anchor node
        node.addChildNode(markerNode)
        node.addChildNode(planeNode)

//        Store ref to anchor
        self.anchors.append(anchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {

        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let markerNode: SCNNode = node.childNodes[0],
            let planeNode: SCNNode = node.childNodes[1],
              let plane = planeNode.geometry as? SCNPlane
              else {return}
        
//        Update visual indicators
        markerNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        print("Removing Anchor")
        
//        Remove ref to selected anchor
        self.anchors.removeAll(where: { $0.identifier == anchor.identifier})
    }
    
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~AR SESSION CONTROLS~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    @objc func handleTap(rec: UITapGestureRecognizer){
        
//        Tap ended
        if rec.state == .ended {
            
//            Onscreen tap position
            let tapLocation: CGPoint = rec.location(in: sceneView)
            
//            Get hitscan from inside anchor's extents
            let hitTestResults = self.sceneView.hitTest(tapLocation, types: [.existingPlaneUsingExtent])
            
            
//            No results found
            if hitTestResults.isEmpty {
                print("No hits on tap")
                return
            }
            
//            If only 1 hit found
            if hitTestResults.count == 1 {
                self.selectedAnchor = hitTestResults.first!.anchor!
                
                print("Anchor selected: ")
                print(self.selectedAnchor)
                
            }
//            Otherwise get closest hit ( a precaution in case of overlap )
            else {
                var closestDistance: CGFloat?;
                for result in hitTestResults {
                    if closestDistance == nil {
                        closestDistance = result.distance
                    }
                    if result.distance < closestDistance! {
                        closestDistance = result.distance
                        self.selectedAnchor = result.anchor!
                    }
                }
                

            }
            
            //                Remove nonselected anchors from session
            for i in 0...self.anchors.count-1 {
                if self.anchors[i].identifier != self.selectedAnchor?.identifier {
                    self.sceneView.session.remove(anchor: self.anchors[i])
                }
            }
//            We've selected our play surface so no need to keep making new anchors
            disablePlaneDetection()
        }
    }
    
//    Restart session w/ selective plane detection
    func enablePlaneDetection(types: ARWorldTrackingConfiguration.PlaneDetection) {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = types
        
        sceneView.session.run(config)
    }
    
//    Restart session w/ no plane detection
    func disablePlaneDetection() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        
        sceneView.session.run(config)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
