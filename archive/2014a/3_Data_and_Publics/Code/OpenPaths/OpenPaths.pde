/*

 OpenPaths example
 ITP Data Rep
 blprnt@blprnt.com
 
 - Loads OpenPaths data from a saved CSV
 - Plots points on a map
 - Uses last week's map zooming functionality
 
 - Also, export to GeoJSON in the last function
 
 */


import java.text.SimpleDateFormat;
import java.util.Date;


//Path to our data file
String dataPath = "../../../data/";
//This arraylist holds all of our PathPoint objects
ArrayList<PathPoint> allPoints = new ArrayList();
//These are all of the points that are currently active
ArrayList<PathPoint> activePoints = new ArrayList();

//Canvas on which to draw the points
PGraphics canvas;

//Initial map bounding box
PVector mapTopLeft = new PVector(-180, 90);
PVector mapBottomRight = new PVector(180, -90);

//Create the simple date format
//2011-06-07 00:03:31
SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd kk:mm:ss");



//This is the time 'playhead'
float currentTime = 0;


void setup() {
  size(1280, 720, P3D);

  //Create canvas
  buildCanvas();

  //Suck in the OpenPaths data
  injestOpenPaths(dataPath + "openpaths_blprnt.csv");
  //Position the points according to the current map frame
  positionPoints(mapTopLeft, mapBottomRight);
  colorPoints();


  //Save out the points to GeoJSON
  pointsToGeoJSON("openpathsLastYear.json");
}

void draw() {
  background(0);
  //currentTime = map(mouseX, 0, width, 0, 1);
  currentTime += 1.0 / (60 * 60);
  if (currentTime > 1) currentTime = 0;


  //Go through all loaded points and render them
  canvas.beginDraw();
  canvas.background(0);
  canvas.noStroke();

  for (PathPoint pp:allPoints) {
    if (pp.timeFraction < currentTime && !activePoints.contains(pp)) activePoints.add(pp);
  }

  //Draw the points
  for (PathPoint pp:activePoints) {
    pp.update();

    pp.render(canvas);
  }

  //Draw the snake
  int snakeLength = 10;
  stroke(255);
  if (activePoints.size() > snakeLength) {
    for (int i = 0; i < snakeLength; i++) {
      PathPoint head = activePoints.get(activePoints.size() - (i + 1));
      PathPoint tail = activePoints.get(activePoints.size() - (i + 2));
      line(head.screenPos.x, head.screenPos.y, tail.screenPos.x, tail.screenPos.y);
    }
  }


  canvas.endDraw();

  image(canvas, 0, 0);

  stroke(255);
  line(currentTime * width, 0, currentTime * width, height);


  //Selection rect
  fill(255, 100);
  rect(mouseX, mouseY, 256, 144);
}


void buildCanvas() {
  canvas = createGraphics(width, height, P3D);
  canvas.smooth(8);
  canvas.beginDraw();
  canvas.background(0);
  canvas.stroke(255);
  canvas.rectMode(CENTER);
  canvas.endDraw();
}

void injestOpenPaths(String url) {
  //Load the requested file in a Table
  Table t = loadTable(url, "header");
  for (TableRow row:t.rows()) {
    //For each row, construct and populate a PathPoint object
    PathPoint pp = new PathPoint();
    pp.lonLat.x = row.getFloat("lon");
    pp.lonLat.y = row.getFloat("lat");
    pp.dateString = row.getString("date");


    try {
      pp.pointDate = sdf.parse(pp.dateString);
      pp.pointTime = pp.pointDate.getTime();
    } 
    catch(Exception e) {

      println(e);
    }
    //Add it to the main arrayList
    allPoints.add(pp);
  }
}


//This positioning code is pretty much copy-pasted from last week's class
void positionPoints(PVector topLeft, PVector bottomRight) {
  for (PathPoint pp:allPoints) {
    float x = map(pp.lonLat.x, topLeft.x, bottomRight.x, 0, width);
    float y = map(pp.lonLat.y, bottomRight.y, topLeft.y, height, 0);
    pp.screenPos = new PVector(x, y);
  }
}

void colorPoints() {

  long startTime = allPoints.get(0).pointTime;
  long endTime = allPoints.get(allPoints.size() - 1).pointTime;
  println(startTime + ":" + endTime);
  colorMode(HSB);
  for (PathPoint pp:allPoints) {
    float c = map(pp.pointTime, startTime, endTime, 0, 255);
    pp.timeFraction = map(pp.pointTime, startTime, endTime, 0, 1);
    pp.col = color(c, 255, 255);
  } 
  colorMode(RGB);
}


void zoomToBox() {
  //calculate the latLon equivalent of the selection box
  PVector topLeft = new PVector();
  topLeft.x = map(mouseX, 0, width, mapTopLeft.x, mapBottomRight.x);
  topLeft.y = map(mouseY, 0, height, mapTopLeft.y, mapBottomRight.y);

  PVector bottomRight = new PVector();
  bottomRight.x = map(mouseX + 256, 0, width, mapTopLeft.x, mapBottomRight.x);
  bottomRight.y = map(mouseY + 144, 0, height, mapTopLeft.y, mapBottomRight.y);

  positionPoints(topLeft, bottomRight);

  mapTopLeft = topLeft;
  mapBottomRight = bottomRight;
}

//Keyboard controls
void mousePressed() {
  zoomToBox();
}

void keyPressed() {
  if (key == ' ') {
    mapTopLeft = new PVector(-180, 90);
    mapBottomRight = new PVector(180, -90);
    positionPoints(mapTopLeft, mapBottomRight);
  }
}

//Code to output to GeoJSON format
void pointsToGeoJSON(String saveURL) {
  //Create the main JSON object
  JSONObject main = new JSONObject();
  main.setString("type", "FeatureCollection");
  //Create the features array
  JSONArray features = new JSONArray();
  //Create a feature object for each path point and add it to the array

  Date today = new Date();
  long lastYear = today.getTime() - (1000 * 60 * 60 * 24 * 365);
  
  int c = 0;
  for (int i = 0; i < allPoints.size(); i++) {
    if (allPoints.get(i).pointDate.getTime() > lastYear) {
      JSONObject pj = new JSONObject();
      pj.setString("type", "Feature");
      //Build geometry
      JSONObject geometry = new JSONObject();
      geometry.setString("type", "Point");
      JSONArray coords = new JSONArray();
      //coords array is in lon, lat order
      coords.setFloat(0, allPoints.get(i).lonLat.x);
      coords.setFloat(1, allPoints.get(i).lonLat.y);
      geometry.setJSONArray("coordinates", coords);

      //Build properties (currently only date)
      JSONObject properties = new JSONObject();
      properties.setString("date", allPoints.get(i).dateString);

      //Add geometry, properties to the feature object
      pj.setJSONObject("geometry", geometry);
      pj.setJSONObject("properties", properties);

      //Add the feature object to the features array
      features.setJSONObject(c, pj);
      c++;
    }

  }

  //Add the features array to the main JSON object
  main.setJSONArray("features", features);

  //Save the JSON Object
  saveJSONObject(main, dataPath + saveURL);
}

