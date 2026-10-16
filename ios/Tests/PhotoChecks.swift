import UIKit
import ImageIO
@main struct PhotoChecks {
 static func main() throws {
  let format = UIGraphicsImageRendererFormat(); format.scale = 1
  let large = UIGraphicsImageRenderer(size: CGSize(width: 3200, height: 2400), format: format).image { context in
   UIColor.systemTeal.setFill(); context.fill(CGRect(x:0,y:0,width:3200,height:2400))
  }.pngData()!
  let result = try compressPhoto(large)
  let source = CGImageSourceCreateWithData(result as CFData, nil)!
  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
  precondition(result.count <= 1_000_000)
  precondition((props[kCGImagePropertyPixelWidth] as! Int) <= 1600)
  precondition((props[kCGImagePropertyPixelHeight] as! Int) <= 1600)
  precondition(result.prefix(3) == Data([255,216,255]))
  do { _ = try compressPhoto(Data([0,1,2])); fatalError("Invalid image accepted") } catch { }
  print("PASS: JPEG conversion, image dimensions/size limit, corrupt image rejection")
 }
}
