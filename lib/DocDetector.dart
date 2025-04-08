import 'dart:math' as math;
import 'package:image/image.dart' as imag;

class DocDetector {
  imag.Image? imageResult;
  List<List<double>>? imageCorners;

  DocDetector({required imag.Image image})
  {
    imageResult = image;
  }

  imag.Image rotateImage({required imag.Image image, required double angleDegrees})
  {
    return imag.copyRotate(image, angle: angleDegrees);
  }

  imag.Image cropImage({required imag.Image image, required List<List<double>> dstPoints})
  {
    double minX = dstPoints[0][0], minY = dstPoints[0][1], maxX = dstPoints[0][0], maxY = dstPoints[0][1];

    for (int i = 1; i < dstPoints.length; i++) {
      if (dstPoints[i][0] < minX) minX = dstPoints[i][0];
      if (dstPoints[i][1] < minY) minY = dstPoints[i][1];
      if (dstPoints[i][0] > maxX) maxX = dstPoints[i][0];
      if (dstPoints[i][1] > maxY) maxY = dstPoints[i][1];
    }

    int cropX = math.max(0, minX.round());
    int cropY = math.max(0, minY.round());
    int cropWidth = (maxX - minX).round();
    int cropHeight = (maxY - minY).round();

    cropWidth = math.max(1, math.min(image.width - cropX, cropWidth));
    cropHeight = math.max(1, math.min(image.height - cropY, cropHeight));

    print("Crop params: x=$cropX, y=$cropY, width=$cropWidth, height=$cropHeight");

    return imag.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );
  }

  imag.Image correctPerspective({
    required imag.Image image,
    required List<List<double>> srcPoints,
    required List<List<double>> dstPoints,
    required int width,
    required int height,
  })
  {
    List<List<double>> H = computePerspectiveTransform(srcPoints: srcPoints, dstPoints: dstPoints);
    imag.Image output = imag.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        List<double> originalPoint = applyPerspectiveTransform(H: H, x: x.toDouble(), y: y.toDouble());
        int origX = originalPoint[0].round();
        int origY = originalPoint[1].round();

        if (origX >= 0 && origX < image.width && origY >= 0 && origY < image.height) {
          output.setPixel(x, y, image.getPixel(origX, origY));
        } else {
          output.setPixel(x, y, imag.ColorInt8.rgb(255, 255, 255));
        }
      }
    }
    return output;
  }

  List<List<double>> computePerspectiveTransform({
    required List<List<double>> srcPoints,
    required List<List<double>> dstPoints,
  })
  {
    List<List<double>> A = List.generate(8, (_) => List<double>.filled(8, 0));
    List<double> B = List<double>.filled(8, 0);

    for (int i = 0; i < 4; i++) {
      double x = srcPoints[i][0], y = srcPoints[i][1];
      double xPrime = dstPoints[i][0], yPrime = dstPoints[i][1];

      A[i * 2] = [x, y, 1, 0, 0, 0, -xPrime * x, -xPrime * y];
      A[i * 2 + 1] = [0, 0, 0, x, y, 1, -yPrime * x, -yPrime * y];

      B[i * 2] = xPrime;
      B[i * 2 + 1] = yPrime;
    }

    List<double> h = solveLinearSystem(A: A, B: B);
    return [
      [h[0], h[1], h[2]],
      [h[3], h[4], h[5]],
      [h[6], h[7], 1]
    ];
  }

  List<double> applyPerspectiveTransform({required List<List<double>> H, required double x, required double y,})
  {
    double w = H[2][0] * x + H[2][1] * y + H[2][2];
    double newX = (H[0][0] * x + H[0][1] * y + H[0][2]) / w;
    double newY = (H[1][0] * x + H[1][1] * y + H[1][2]) / w;
    return [newX, newY];
  }

  List<double> solveLinearSystem({required List<List<double>> A, required List<double> B,})
  {
    int n = B.length;
    List<double> x = List<double>.filled(n, 0);

    for (int i = 0; i < n; i++) {
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (A[k][i].abs() > A[maxRow][i].abs()) {
          maxRow = k;
        }
      }

      List<double> temp = A[i];
      A[i] = A[maxRow];
      A[maxRow] = temp;

      double t = B[i];
      B[i] = B[maxRow];
      B[maxRow] = t;

      for (int k = i + 1; k < n; k++) {
        double factor = A[k][i] / A[i][i];
        B[k] -= factor * B[i];
        for (int j = i; j < n; j++) {
          A[k][j] -= factor * A[i][j];
        }
      }
    }

    for (int i = n - 1; i >= 0; i--) {
      double sum = B[i];
      for (int j = i + 1; j < n; j++) {
        sum -= A[i][j] * x[j];
      }
      x[i] = sum / A[i][i];
    }

    return x;
  }

  List<double> lineFromPointAngle({required int x0, required int y0, required double angle,})
  {
    double rad = angle * math.pi / 180;
    double m = math.tan(rad);
    double b = y0 - m * x0;
    return [m, b];
  }

  List<double> intersection({required List<double> line1, required List<double> line2,})
  {
    double m1 = line1[0], b1 = line1[1], m2 = line2[0], b2 = line2[1];
    int x = ((b2 - b1) / (m1 - m2)).round();
    int y = (m1 * x + b1).round();
    return [x.toDouble(), y.toDouble()];
  }

  List<List<double>> findCorners({
    required double angleTop,
    required double angleBottom,
    required double angleLeft,
    required double angleRight,
    required int topX,
    required int topY,
    required int bottomX,
    required int bottomY,
    required int leftX,
    required int leftY,
    required int rightX,
    required int rightY,
    required int originalWidth,
    required int originalHeight,
    required int binWidth,
    required int binHeight,
  })
  {
    double scaleX = originalWidth / binWidth;
    double scaleY = originalHeight / binHeight;

    List<double> topLine = lineFromPointAngle(x0: topX, y0: topY, angle: angleTop);
    List<double> bottomLine = lineFromPointAngle(x0: bottomX, y0: bottomY, angle: angleBottom);
    List<double> leftLine = lineFromPointAngle(x0: leftX, y0: leftY, angle: angleLeft);
    List<double> rightLine = lineFromPointAngle(x0: rightX, y0: rightY, angle: angleRight);

    List<double> topLeft = intersection(line1: topLine, line2: leftLine);
    List<double> topRight = intersection(line1: topLine, line2: rightLine);
    List<double> bottomLeft = intersection(line1: bottomLine, line2: leftLine);
    List<double> bottomRight = intersection(line1: bottomLine, line2: rightLine);

    // Ajustar para a escala da imagem original e limitar aos bounds
    return [
      [math.max(0, math.min(originalWidth - 1, topLeft[0] * scaleX)), math.max(0, math.min(originalHeight - 1, topLeft[1] * scaleY))],
      [math.max(0, math.min(originalWidth - 1, topRight[0] * scaleX)), math.max(0, math.min(originalHeight - 1, topRight[1] * scaleY))],
      [math.max(0, math.min(originalWidth - 1, bottomRight[0] * scaleX)), math.max(0, math.min(originalHeight - 1, bottomRight[1] * scaleY))],
      [math.max(0, math.min(originalWidth - 1, bottomLeft[0] * scaleX)), math.max(0, math.min(originalHeight - 1, bottomLeft[1] * scaleY))],
    ];
  }

  List<List<double>> getCorrectedCornersPerspective({
    required List<List<double>> srcPoints,
  })
  {
    double minX = math.min(
      math.min(srcPoints[0][0], srcPoints[3][0]),
      math.min(srcPoints[1][0], srcPoints[2][0]),
    );
    double maxX = math.max(
      math.max(srcPoints[0][0], srcPoints[3][0]),
      math.max(srcPoints[1][0], srcPoints[2][0]),
    );

    double minY = math.min(
      math.min(srcPoints[0][1], srcPoints[1][1]),
      math.min(srcPoints[2][1], srcPoints[3][1]),
    );
    double maxY = math.max(
      math.max(srcPoints[0][1], srcPoints[1][1]),
      math.max(srcPoints[2][1], srcPoints[3][1]),
    );

    return [
      [minX, minY],
      [maxX, minY],
      [maxX, maxY],
      [minX, maxY],
    ];
  }

  void catchDocument({required imag.Image image,required int width,required int height,})
  {
    imag.Image imageBin = imag.copyResize(image, width: 800);
    imageBin = imag.grayscale(imageBin);
    imageBin = imag.gaussianBlur(imageBin, radius: 5);
    imageBin = imag.sobel(imageBin);
    imageBin = binarizeImage(image: imageBin);

    int imageBinWidth = imageBin.width;
    int imageBinHeight = imageBin.height;

    int imageBinWidthEnd = imageBinWidth - 1;
    int imageBinHeightEnd = imageBinHeight - 1;

    List<List<int>> edges = List.generate(4, (_) => [0, 0]);  // [top, bottom, left, right]

    double? angleTop;
    double? angleBottom;
    double? angleLeft;
    double? angleRight;

    int imageBinMiddleHeight = imageBinHeight ~/ 2;
    int imageBinMiddleWidth = imageBinWidth ~/ 2;

    int margin = (width * 0.1333).round();
    List<int> gapIterX = [imageBinMiddleWidth - margin, imageBinMiddleWidth + margin];
    List<int> gapIterY = [imageBinMiddleHeight - margin, imageBinMiddleHeight + margin];

    int xPoint = -1;
    int yPoint = -1;

    double ts = 3;

    for (int y = 0; y < imageBinMiddleHeight; y++) {
      int whiteCount = 0;
      for (int x = gapIterX[0]; x < gapIterX[1]; x++) {
        if (imageBin.getPixel(x, y).r == 255 &&
            imageBin.getPixel(x, y).g == 255 &&
            imageBin.getPixel(x, y).b == 255) {
          whiteCount++;
          xPoint = x;
        }
      }
      if (whiteCount > ts) {
        edges[0][0] = xPoint == -1 ? imageBinMiddleWidth : xPoint;
        edges[0][1] = y;
        angleTop = verifyLineAngle(
          image: imageBin,
          startX: edges[0][0],
          startY: edges[0][1],
          threshold: margin,
          horizontalOnly: true,
        );
        if (angleTop != null) {
          if (angleTop > 1 && angleTop < 20) {
            imageBin = rotateImage(image: imageBin, angleDegrees: -angleTop);
            image = rotateImage(image: image, angleDegrees: -angleTop);
          } else if (angleTop > 100 && angleTop < 178) {
            imageBin = rotateImage(image: imageBin, angleDegrees: 180 - angleTop);
            image = rotateImage(image: image, angleDegrees: 180 - angleTop);
          } else {
            break;
          }
        }
      }
    }

    xPoint = -1;
    for (int y = imageBinHeightEnd; y > imageBinMiddleHeight; y--) {
      int whiteCount = 0;
      for (int x = gapIterX[0]; x < gapIterX[1]; x++) {
        if (imageBin.getPixel(x, y).r == 255 &&
            imageBin.getPixel(x, y).g == 255 &&
            imageBin.getPixel(x, y).b == 255) {
          whiteCount++;
          xPoint = x;
        }
      }
      if (whiteCount > ts) {
        edges[1][0] = xPoint == -1 ? imageBinMiddleWidth : xPoint;
        edges[1][1] = y;
        angleBottom = verifyLineAngle(
          image: imageBin,
          startX: edges[1][0],
          startY: edges[1][1],
          threshold: margin,
          horizontalOnly: true,
        );
        if (angleBottom != null) {
          break;
        }
      }
    }

    for (int x = 0; x < imageBinMiddleWidth; x++) {
      int whiteCount = 0;
      for (int y = gapIterY[0]; y < gapIterY[1]; y++) {
        if (imageBin.getPixel(x, y).r == 255 &&
            imageBin.getPixel(x, y).g == 255 &&
            imageBin.getPixel(x, y).b == 255) {
          whiteCount++;
          yPoint = y;
        }
      }
      if (whiteCount > ts) {
        edges[2][0] = x;
        edges[2][1] = yPoint == -1 ? imageBinMiddleHeight : yPoint;
        angleLeft = verifyLineAngle(
          image: imageBin,
          startX: edges[2][0],
          startY: edges[2][1],
          threshold: margin,
          horizontalOnly: false,
        );
        if (angleLeft != null) {
          break;
        }
      }
    }

    yPoint = -1;
    for (int x = imageBinWidthEnd; x > imageBinMiddleWidth; x--) {
      int whiteCount = 0;
      for (int y = gapIterY[0]; y < gapIterY[1]; y++) {
        if (imageBin.getPixel(x, y).r == 255 &&
            imageBin.getPixel(x, y).g == 255 &&
            imageBin.getPixel(x, y).b == 255) {
          whiteCount++;
          yPoint = y;
        }
      }
      if (whiteCount > ts) {
        edges[3][0] = x;
        edges[3][1] = yPoint == -1 ? imageBinMiddleHeight : yPoint;
        angleRight = verifyLineAngle(
          image: imageBin,
          startX: edges[3][0],
          startY: edges[3][1],
          threshold: margin,
          horizontalOnly: false,
        );
        if (angleRight != null) {
          break;
        }
      }
    }

    if (angleBottom != null && angleTop != null && angleRight != null && angleLeft != null) {
      List<List<double>> corners = findCorners(
        angleTop: angleTop,
        angleBottom: angleBottom,
        angleLeft: angleLeft,
        angleRight: angleRight,
        topX: edges[0][0],
        topY: edges[0][1],
        bottomX: edges[1][0],
        bottomY: edges[1][1],
        leftX: edges[2][0],
        leftY: edges[2][1],
        rightX: edges[3][0],
        rightY: edges[3][1],
        originalWidth: width,
        originalHeight: height,
        binWidth: imageBinWidth,
        binHeight: imageBinHeight,
      );
      imageCorners = corners;
      print("Corners: $corners");

      List<List<double>> dstPoints = getCorrectedCornersPerspective(srcPoints: corners);
      print("DstPoints: $dstPoints");

      image = correctPerspective(
        image: image,
        srcPoints: dstPoints,
        dstPoints: corners,
        width: width,
        height: height,
      );
      imageResult = cropImage(image: image, dstPoints: dstPoints);
      print("Image processed: ${imageResult!.width}x${imageResult!.height}");
    } else {
      print("Edge detection failed: top=$angleTop, bottom=$angleBottom, left=$angleLeft, right=$angleRight");
      imageResult = imageBin;
    }
  }

  imag.Image binarizeImage({
    required imag.Image image,
    int threshold = 128,
    bool invert = false,
  })
  {
    final result = imag.copyResize(image);

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        final luminance = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt();

        final newValue = luminance > threshold ? 255 : 0;

        final finalValue = invert ? 255 - newValue : newValue;

        result.setPixelRgb(x, y, finalValue, finalValue, finalValue);
      }
    }

    return result;
  }

  int countWhitePixels({
    required imag.Image image,
    required int startX,
    required int startY,
    required double angle,
  })
  {
    double radian = angle * math.pi / 180;
    double slope = math.tan(radian);

    int width = image.width;
    int height = image.height;
    int count = 0;

    int xStart = 0;
    int yStart = (startY - slope * startX).round();
    int xEnd = width - 1;
    int yEnd = (startY + slope * (width - 1 - startX)).round();

    List<int> clippedStart = clipToBounds(
      startX: startX,
      startY: startY,
      x: xStart,
      y: yStart,
      width: width,
      height: height,
    );
    List<int> clippedEnd = clipToBounds(
      startX: startX,
      startY: startY,
      x: xEnd,
      y: yEnd,
      width: width,
      height: height,
    );

    xStart = clippedStart[0];
    yStart = clippedStart[1];
    xEnd = clippedEnd[0];
    yEnd = clippedEnd[1];

    int dx = (xEnd - xStart).abs();
    int dy = (yEnd - yStart).abs();
    int sx = xStart < xEnd ? 1 : -1;
    int sy = yStart < yEnd ? 1 : -1;
    int err = dx - dy;

    int x = xStart;
    int y = yStart;

    while (true) {
      if (x >= 0 && x < width && y >= 0 && y < height) {
        imag.Color pixel = image.getPixel(x, y);
        // Ajuste: considerar pixels com alta intensidade como "brancos"
        if (pixel.r > 200 && pixel.g > 200 && pixel.b > 200) {
          count++;
        }
      }

      if (x == xEnd && y == yEnd) {
        break;
      }

      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }

    return count;
  }

  List<int> clipToBounds({
    required int startX,
    required int startY,
    required int x,
    required int y,
    required int width,
    required int height,
  })
  {
    if (x < 0) {
      y = startY + ((y - startY) * (-startX) / (x - startX)).round();
      x = 0;
    } else if (x >= width) {
      y = startY + ((y - startY) * (width - 1 - startX) / (x - startX)).round();
      x = width - 1;
    }

    if (y < 0) {
      x = startX + ((x - startX) * (-startY) / (y - startY)).round();
      y = 0;
    } else if (y >= height) {
      x = startX + ((x - startX) * (height - 1 - startY) / (y - startY)).round();
      y = height - 1;
    }

    return [x, y];
  }

  double? verifyLineAngle({
    required imag.Image image,
    required int startX,
    required int startY,
    required int threshold,
    required bool horizontalOnly,
  })
  {
    double bestAngle = -1;
    int maxWhitePixels = 0;

    List<List<int>> ranges = horizontalOnly ? [[0, 20], [170, 190]] : [[75, 110]];
    for (List<int> range in ranges) {
      for (int angle = range[0]; angle < range[1]; angle++) {
        int whitePixels = countWhitePixels(
          image: image,
          startX: startX,
          startY: startY,
          angle: angle.toDouble(),
        );

        if (whitePixels > maxWhitePixels) {
          maxWhitePixels = whitePixels;
          bestAngle = angle.toDouble();
        }
      }
    }
    return (maxWhitePixels >= threshold) ? bestAngle : null;
  }
}