//
//  CanvasViewController.swift
//  LinkedIdeas
//
//  Created by Felipe Espinoza Castillo on 29/08/2016.
//  Copyright © 2016 Felipe Espinoza Dev. All rights reserved.
//

import Cocoa

protocol GraphConcept {
  var rect: NSRect { get }
  var attributedStringValue: NSAttributedString { get }
  var isSelected: Bool { get set }
}

protocol GraphLink {
  var color: NSColor { get }
  
  var originPoint: NSPoint { get }
  var targetPoint: NSPoint { get }
  
  var originRect: NSRect { get }
  var targetRect: NSRect { get }
}

extension Concept: GraphConcept {}

extension Link: GraphLink {
  var originRect: NSRect { return origin.rect }
  var targetRect: NSRect { return target.rect }
}

struct DrawableConcept: DrawableElement {
  let concept: GraphConcept
  
  func draw() {
    concept.attributedStringValue.draw(at: concept.rect.origin)
    drawSelectedRing()
  }
  
  func drawSelectedRing() {
    guard concept.isSelected else { return }
    
    NSColor.red.set()
    NSBezierPath(rect: concept.rect).stroke()
  }
}

struct DrawableLink: DrawableElement {
  let link: GraphLink
  
  func draw() {
    link.color.set()
    constructArrow()?.bezierPath().fill()
  }
  
  func constructArrow() -> Arrow? {
    let originPoint = link.originPoint
    let targetPoint = link.targetPoint
    
    if let intersectionPointWithOrigin = link.originRect.firstIntersectionTo(targetPoint),
       let intersectionPointWithTarget = link.targetRect.firstIntersectionTo(originPoint) {
      return Arrow(p1: intersectionPointWithOrigin, p2: intersectionPointWithTarget)
    } else {
      return nil
    }
  }
}

extension NSResponder {
  var identifierString: String {
    return "\(type(of: self))"
  }
  
  func print(_ message: String) {
    Swift.print("\(identifierString): \(message)")
  }
}

extension NSEvent {
  func isSingleClick() -> Bool { return clickCount == 1 }
  func isDoubleClick() -> Bool { return clickCount == 2 }
}

class CanvasViewController: NSViewController {
  @IBOutlet weak var canvasView: CanvasView!
  @IBOutlet weak var scrollView: NSScrollView!
  
  var stateManager = StateManager(initialState: .canvasWaiting)
  var currentState: CanvasState {
    get {
      return stateManager.currentState
    }
    set(newState) {
      stateManager.currentState = newState
    }
  }
  
  lazy var textField: NSTextField = {
    let textField = NSTextField()
    textField.isHidden = true
    textField.isEditable = false
    return textField
  }()
  
  var document: LinkedIdeasDocument! {
    didSet {
      print("- didSetDocument \(document)")
      document.observer = self
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    print("-viewDidLoad")
    canvasView.dataSource = self
    
    // modify canvas frame (size)
    // and scroll to center of it
    canvasView.frame = NSMakeRect(0, 0, 3000, 2000)
    let canvasViewCenterForScroll = NSMakePoint(
      (canvasView.frame.center.x - scrollView.frame.center.x),
      (canvasView.frame.center.y - scrollView.frame.center.y)
    )
    scrollView.scroll(canvasViewCenterForScroll)
    
    textField.delegate = self
    canvasView.addSubview(textField)
    
    stateManager.delegate = self
  }
  
  override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    print("-prepareForSegue")
  }
  
  func convertToCanvasCoordinates(point: NSPoint) -> NSPoint {
    return canvasView.convert(point, from: nil)
  }
  
  func clickedConcepts(atPoint clickedPoint: NSPoint) -> [Concept]? {
    let results = document.concepts.filter { (concept) -> Bool in
      return concept.rect.contains(clickedPoint)
    }
    guard results.count > 0 else { return nil }
    return results
  }
}

// MARK: - MouseEvents
extension CanvasViewController {
  override func mouseDown(with event: NSEvent) {
    let point = convertToCanvasCoordinates(point: event.locationInWindow)
    
    if event.isSingleClick() {
      if let clickedConcepts = clickedConcepts(atPoint: point) {
        try! stateManager.toSelectedElements(elements: clickedConcepts)
      } else {
        try! stateManager.toCanvasWaiting()
      }
    } else if event.isDoubleClick() {
      try! stateManager.toNewConcept(atPoint: point)
    }
  }
}

// MARK: - CanvasViewDataSource
extension CanvasViewController: CanvasViewDataSource {
  var drawableElements: [DrawableElement] {
    var elements: [DrawableElement] = []
    
    elements += document.concepts.map {
      DrawableConcept(concept: $0 as GraphConcept) as DrawableElement
    }
    
    elements += document.links.map {
      DrawableLink(link: $0 as GraphLink) as DrawableElement
    }
    
    return elements
  }
}

// MARK: - DocumentObserver
extension CanvasViewController: DocumentObserver {
  func documentChanged(withElement element: Element) {
    canvasView.needsDisplay = true
  }
}

// MARK: - NewStateManagerDelegate
extension CanvasViewController: NewStateManagerDelegate {
  // basic
  func transitionSuccesfull() {
    canvasView.needsDisplay = true
  }
  
  func transitionedToNewConcept(fromState: CanvasState) {}
  func transitionedToCanvasWaiting(fromState: CanvasState) {}
  func transitionedToCanvasWaitingSavingConcept(fromState: CanvasState, point: NSPoint, text: NSAttributedString) {}
  func transitionedToSelectedElements(fromState: CanvasState) {}
}

// MARK: NSTextFieldDelegate
extension CanvasViewController: NSTextFieldDelegate {
  // Invoked when users press keys with predefined bindings in a cell of the specified control.
  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    switch commandSelector {
    case #selector(NSResponder.insertNewline(_:)):
      try! stateManager.toCanvasWaiting(savingConceptWithText: control.attributedStringValue)
      return true
    default:
      return false
    }
  }
}
