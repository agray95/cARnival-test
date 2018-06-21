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
    
//    Probably gone soon
    var detectionPaused: Bool = false
    
//    Max depth for occluders
    let gamespaceDepth: CGFloat = 3.0
    
//    Default plane detection options
    let surfaceTypes: ARWorldTrackingConfiguration.PlaneDetection = [.vertical]
    
    enum UserState {
        case Browse
        case Play
    }
    
    var currentState: UserState = UserState.Browse
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
        
        
//        Currently throws error due to XCode 10 bug(?)
//        guard
//            let refImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil)
//        else { fatalError("Missing expeced asset catalog resources") }
        
        let calendar = ARReferenceImage(UIImage(named: "testPoster")!.cgImage!, orientation: CGImagePropertyOrientation.up, physicalWidth: 0.73)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = [calendar]

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
        
//        If unable to cast to PlaneAnchor, attempt to handle as ImageAnchor
        guard
            let planeAnchor = anchor as? ARPlaneAnchor
        else { handleAddImageAnchor(renderer, didAdd: node, for: anchor); return }
        
//        Add spherical marker
        let marker = SCNSphere(radius: 0.01)
        let markerNode = SCNNode(geometry: marker)
        markerNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        markerNode.opacity = 0.8
        
//        Add extent indicator plane
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
    
    func handleAddImageAnchor(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor){
        guard
            let imgAnchor = anchor as? ARImageAnchor
        else { return }
        
        print("Adding image anchor!")
        
        let imgAnchorMarker = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0.01)
        let markerNode = SCNNode(geometry: imgAnchorMarker)
        markerNode.opacity = 1.0
        markerNode.simdPosition = node.simdPosition
        
        //        Add extent indicator plane
        let plane = SCNPlane(width: CGFloat(imgAnchor.referenceImage.physicalSize.width), height: CGFloat(imgAnchor.referenceImage.physicalSize.height))
        let planeNode = SCNNode(geometry: plane)
//        planeNode.simdPosition = float3(imgAnchor.center.x, 0, imgAnchor.center.z)
        planeNode.opacity = 0.25
        planeNode.eulerAngles.x = -.pi / 2
        
        //        Add visual indicator nodes to anchor node
        node.addChildNode(planeNode)
        
        node.addChildNode(markerNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {

        guard
            let planeAnchor = anchor as? ARPlaneAnchor
            else { handleUpdateImageAnchor(renderer, didUpdate: node, for: anchor); return }
        
        guard
            let markerNode: SCNNode = node.childNodes[0],
            let planeNode: SCNNode = node.childNodes[1],
            let plane = planeNode.geometry as? SCNPlane
        else { return }
        
//        Update visual indicators
        markerNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
    }
    
    func handleUpdateImageAnchor(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard
            let imgAnchor = anchor as? ARImageAnchor
        else { return }
        print("Updating image anchor!")
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
//        Remove ref to selected anchor
        self.anchors.removeAll(where: { $0.identifier == anchor.identifier})
    }
    
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~AR SESSION CONTROLS~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    @objc func handleTap(rec: UITapGestureRecognizer){
        
        if self.detectionPaused {
            enablePlaneDetection(types: self.surfaceTypes)
            return
        }
        
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
            
//            Remove nonselected anchors from session
            for i in 0...self.anchors.count-1 {
                if self.anchors[i].identifier != self.selectedAnchor?.identifier {
                    self.sceneView.session.remove(anchor: self.anchors[i])
                }
            }
            
//            We've selected our play surface so no need to keep making new anchors
            disablePlaneDetection()
            
//            Possibly move this functionality to a button or something
            spawnScene()
        }
    }
    
//    Restart session w/ selective plane detection
    func enablePlaneDetection(types: ARWorldTrackingConfiguration.PlaneDetection) {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = types
        
        sceneView.session.run(config)

//        Take care of resetting selected object here
        if self.selectedAnchor != nil {
            
            guard
                let rootAnchor = self.selectedAnchor! as? ARPlaneAnchor,
                let rootNode = self.sceneView.node(for: rootAnchor)
            else { print("Error getting root node/anchor"); return }
            
            for node in rootNode.childNodes {
                node.removeFromParentNode()
            }
            
//            Remove current game stage anchor from scene
            self.sceneView.session.remove(anchor: rootAnchor)
        }
        
        detectionPaused = false
    }
    
//    Restart session w/ no plane detection
    func disablePlaneDetection() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        
        sceneView.session.run(config)
        
        detectionPaused = true
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
    
    func session
    
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    //~~~~~~GAME FUNCTIONALITY~~~~~~~~~~~~~~
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    func spawnScene(){
        
        guard
            let rootAnchor = self.selectedAnchor! as? ARPlaneAnchor,
            let rootNode = self.sceneView.node(for: rootAnchor)
        else {return}
        
        let objScn = SCNScene(named: "art.scnassets/ship.scn")
        
        let rootPosition = rootAnchor.center
        
//        "Bullseye"
        let bigDonut = SCNTorus(ringRadius: 0.1, pipeRadius: 0.01)
        let donutNode = SCNNode(geometry: bigDonut)
        donutNode.simdPosition = rootPosition
        donutNode.opacity = 1.0
        
//        Planes
        let testObjNode = objScn!.rootNode.childNodes.first!
        testObjNode.simdPosition = rootPosition
        testObjNode.opacity = 1.0
        testObjNode.eulerAngles.x = -.pi/2
        testObjNode.scale = SCNVector3(0.25, 0.25, 0.25)
        
//        Add bullseye & planes to scene
        rootNode.addChildNode(testObjNode)
        rootNode.addChildNode(donutNode)
        
//        Create Gamestage Occluders
        spawnOccluders(rootNode: rootNode, rootAnchor: rootAnchor)
        
    }
    
    
    enum OccluderType {
        case Top
        case Bottom
        case Left
        case Right
    }
    
    func spawnOccluders(rootNode: SCNNode, rootAnchor: ARPlaneAnchor){
        createOccluder(rootNode: rootNode, rootAnchor: rootAnchor, type: OccluderType.Top)
        createOccluder(rootNode: rootNode, rootAnchor: rootAnchor, type: OccluderType.Bottom)
        createOccluder(rootNode: rootNode, rootAnchor: rootAnchor, type: OccluderType.Left)
        createOccluder(rootNode: rootNode, rootAnchor: rootAnchor, type: OccluderType.Right)
    }
    
//    Spawn occluders to hide contents of gamestage from the outside. "Window" effect
    func createOccluder(rootNode: SCNNode, rootAnchor: ARPlaneAnchor, type: OccluderType) {
        let rootExtent = rootAnchor.extent
        let rootPosition = rootAnchor.center
        
        var occluderPlane: SCNPlane;
        
//        Set the width/height of occluder planes
        switch type {
            case OccluderType.Top, OccluderType.Bottom:
                occluderPlane = SCNPlane(width: CGFloat(rootExtent.x), height: self.gamespaceDepth)
                break
            case OccluderType.Right, OccluderType.Left:
                occluderPlane = SCNPlane(width: CGFloat(rootExtent.z), height: self.gamespaceDepth)
                break
        }
        
        let occluderNode = SCNNode(geometry: occluderPlane)
        
//        Clear material but still in buffer
        occluderPlane.materials.first?.colorBufferWriteMask = []
        
//        Set position & rotation of occluders
        switch type {
            case OccluderType.Top:
                occluderNode.simdPosition = float3(rootPosition.x, Float(CGFloat(rootPosition.y) - gamespaceDepth/2.0), Float(CGFloat(rootPosition.z) - CGFloat(rootExtent.z)/2.0))
                occluderNode.eulerAngles.y = -.pi
                break
            case OccluderType.Bottom:
                occluderNode.simdPosition = float3(rootPosition.x, Float(CGFloat(rootPosition.y) - gamespaceDepth/2.0), Float(CGFloat(rootPosition.z) + CGFloat(rootExtent.z)/2.0))
                break
            case OccluderType.Left:
                occluderNode.simdPosition = float3(Float(CGFloat(rootPosition.x) - CGFloat(rootExtent.x)/2.0), Float(CGFloat(rootPosition.y) - gamespaceDepth/2.0), rootPosition.z)
                occluderNode.eulerAngles.y = -.pi/2
                break
            case OccluderType.Right:
                occluderNode.simdPosition = float3(Float(CGFloat(rootPosition.x) + CGFloat(rootExtent.x)/2.0), Float(CGFloat(rootPosition.y) - gamespaceDepth/2.0), rootPosition.z)
                occluderNode.eulerAngles.y = .pi/2
                break
        }
        
//        Add the occluder to the anchor node
        rootNode.addChildNode(occluderNode)
        
    }
}


