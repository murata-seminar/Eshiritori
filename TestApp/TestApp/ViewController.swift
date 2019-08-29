//
//  ViewController.swift
//  TestApp
//
//  Created by kmurata on 2019/08/29.
//  Copyright © 2019 kmurata seminar. All rights reserved.
//
// https://anthrgrnwrld.hatenablog.com/entry/2016/07/14/230929
// を参考に作成しています。
//

import UIKit

class ViewController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var canvasView: UIImageView!
    
    var lastPoint: CGPoint? //直前のタッチ座標の保存用
    var lineWidth: CGFloat? //描画用の線の太さの保存用
    var drawColor = UIColor() //描画色の保存
    var bezierPath = UIBezierPath() //お絵かきに使用
    let defaultLineWidth: CGFloat = 10.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0   //最小拡大率
        scrollView.maximumZoomScale = 4.0   //最大拡大率
        scrollView.zoomScale = 1.0          //拡大率初期値
        
        prepareDrawing()    //お絵かき準備
    }

    /**
     拡大縮小に対応させるためにOverride
    */
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.canvasView
    }
    
    /**
     キャンパスの準備（何も描かれていないUIImageの作成）
    */
    func prepareCanvas(){
        let canvasSize = CGSize(width: view.frame.width * 2, height: view.frame.width * 2)
        let canvasRect = CGRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height)
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 0.0)
        var firstCanvasImage = UIImage()
        firstCanvasImage.draw(in: canvasRect)
        firstCanvasImage = UIGraphicsGetImageFromCurrentImageContext()!
        canvasView.contentMode = .scaleAspectFit
        canvasView.image = firstCanvasImage
        UIGraphicsEndImageContext()
    }
    
    /**
     UIGestureRecognizerでお絵かき対応。1本指でなぞった時のみ対応とする。
    */
    private func prepareDrawing(){
        //描く手段（色鉛筆？クレヨン？など）
        let myDraw = UIPanGestureRecognizer(target: self, action: #selector(self.drawGesture(sender:)))
        myDraw.maximumNumberOfTouches = 1
        self.scrollView.addGestureRecognizer(myDraw)
        
        //実際のお絵かきで言うキャンバスの準備（何も描かれていないUIImageの作成）
        prepareCanvas()
    }
    
    /**
     draw動作
    */
    @objc func drawGesture(sender: AnyObject){
        guard let drawGesture = sender as? UIPanGestureRecognizer else{
            print("drawGesture Error happend.")
            return
        }
        
        guard let canvas = self.canvasView.image else{
            fatalError("self.picturView.image not found")
        }
        
        //線の太さと色を指定する
        lineWidth = defaultLineWidth
        drawColor = UIColor.black
        
        let touchPoint = drawGesture.location(in: canvasView)   //タッチ座標を取得
        switch drawGesture.state{
        case .began:
            lastPoint = touchPoint  //タッチ座標をlastTouchPointとして保存
            
            //touchPointの座標はscrollView基準なのでキャンバスの大きさに合わせた座標に変換
            //lastPointをキャンバスサイズにコンバート
            let lastPointForCanvasSize = convertPointForCanvasSize(originalPoint: lastPoint!, canvasSize: canvas.size)
            bezierPath.lineCapStyle = .round    //端を丸く
            bezierPath.lineWidth = defaultLineWidth //描画線の太さ
            bezierPath.move(to: lastPointForCanvasSize)
            
        case .changed:
            let newPoint = touchPoint   //タッチポイントを最新として保存
            
            //Drawの実行
            let imageAfterDraw = drawGestureAtChanged(canvas: canvas, lastPoint: lastPoint!, newPoint: newPoint, bezierPath: bezierPath)
            self.canvasView.image = imageAfterDraw
            lastPoint = newPoint
            
        case .ended:
            print("Finish dragging")
            
        default:
            ()
        }
        
    }
    
    /**
        UIGestureRecognizerのStatusが.Changedの時に実行するDraw動作
     - parameter canvas : キャンバス
     - parameter lastPoint : 最新のタッチから直前に保存した座標
     - parameter newPoint : 最新のタッチの座標座標
     - parameter bezierPath : 線の設定などが保管されたインスタンス
    */
    func drawGestureAtChanged(canvas: UIImage, lastPoint: CGPoint, newPoint: CGPoint, bezierPath: UIBezierPath) -> UIImage {
        
        //最新のtouchPointとLastPointからmiddlePointを算出
        let middlePoint = CGPoint(x: (lastPoint.x + newPoint.x) / 2, y: (lastPoint.y + newPoint.y) / 2)
        
        //各ポイントの座標はScrollView基準なのでキャンバスのお大きさに合わせた座標に変換
        //各ポイントをキャンバスサイズにコンバート
        let middlePointForCanvas = convertPointForCanvasSize(originalPoint: middlePoint, canvasSize: canvas.size)
        let lastPointForCanvas = convertPointForCanvasSize(originalPoint: lastPoint, canvasSize: canvas.size)
        
        bezierPath.addQuadCurve(to: middlePointForCanvas, controlPoint: lastPointForCanvas) //曲線を描く
        UIGraphicsBeginImageContextWithOptions(canvas.size, false, 0.0)
        let canvasRect = CGRect(x: 0, y: 0, width: canvas.size.width, height: canvas.size.height)
        self.canvasView.image?.draw(in: canvasRect)
        drawColor.setStroke()
        bezierPath.stroke()
        let imageAfterDraw = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return imageAfterDraw
    }
    
    /**
     (おまじない)座標をキャンバスのサイズに準じたものに変換する
     
     - parameter originalPoint : 座標
     - parameter canvasSize : キャンバスのサイズ
     - returns : キャンバス基準に変換した座標
     */
    func convertPointForCanvasSize(originalPoint: CGPoint, canvasSize: CGSize) -> CGPoint {
        
        let viewSize = scrollView.frame.size
        var ajustContextSize = canvasSize
        var diffSize: CGSize = CGSize(width: 0, height: 0)
        let viewRatio = viewSize.width / viewSize.height
        let contextRatio = canvasSize.width / canvasSize.height
        let isWidthLong = viewRatio < contextRatio ? true : false
        
        if isWidthLong {
            
            ajustContextSize.height = ajustContextSize.width * viewSize.height / viewSize.width
            diffSize.height = (ajustContextSize.height - canvasSize.height) / 2
            
        } else {
            
            ajustContextSize.width = ajustContextSize.height * viewSize.width / viewSize.height
            diffSize.width = (ajustContextSize.width - canvasSize.width) / 2
            
        }
        
        let convertPoint = CGPoint(x: originalPoint.x * ajustContextSize.width / viewSize.width - diffSize.width,
                                   y: originalPoint.y * ajustContextSize.height / viewSize.height - diffSize.height)
        
        
        return convertPoint
        
    }
}

