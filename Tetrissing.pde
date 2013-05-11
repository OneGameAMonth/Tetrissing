/*
 @pjs preload="data/images/bk.png,data/fonts/null_terminator_2x.png,data/images/red.png,data/images/blue.png,data/images/babyblue.png,data/images/green.png, data/images/orange.png, data/images/pink.png";
 */ 
import ddf.minim.*;

final boolean DEBUG = false;

final int T_SHAPE = 0;
final int L_SHAPE = 1;
final int J_SHAPE = 2;
final int I_SHAPE = 3;
final int O_SHAPE = 4;
final int Z_SHAPE = 5;
final int S_SHAPE = 6;

final int EMPTY    = 0;
final int RED      = 1;
final int ORANGE   = 2;
final int PINK     = 3;
final int BLUE     = 4;
final int GREEN    = 5;
final int PURPLE   = 6;
final int BABYBLUE = 7;
final int WHITE    = 8;

// TODO: fix this
PImage[] images = new PImage[9];

int level;
int score;

final int SCORE_1_LINE  = 100;
final int SCORE_2_LINES = 250;
final int SCORE_3_LINES = 500;
final int SCORE_4_LINES = 600;

final int MAX_LEVELS = 5;
int scoreForThisLevel;
int[] scoreReqForNextLevel = new int[]{  SCORE_4_LINES * 2,
                                         SCORE_4_LINES * 4,
                                         SCORE_4_LINES * 6,
                                         SCORE_4_LINES * 8,
                                         SCORE_4_LINES * 10};

Ticker clearLineTicker;



boolean clearingLines = false;

int[] shapeStats;

Shape currentShape;
int currShapeCol;
int currShapeRow;

Queue nextPieceQueue;

PImage backgroundImg;

//
int ghostShapeCol;
int ghostShapeRow;

boolean hasLostGame;
boolean didDrawGameOver = false;


final float TAP_LEN_IN_SEC = 0.1f;
boolean holdingDownLeft = false;
float moveBuffer = 0f;

boolean holdingDownRight = false;
float rightBuffer = 0f;

float blocksPerSecond = 10.0f;

// Add 2 for left and right borders and 1 for floor
final int NUM_COLS = 12;  // 10 cols + 2 for border
final int NUM_ROWS = 25;  // 25 rows + 1 floor + 4 extra
final int CUT_OFF_INDEX = 3;

// Don't include the floor
final int LAST_ROW_INDEX = NUM_ROWS - 2;

// TODO: refactor to BLOCK_SIZE
int BOX_SIZE = 16;

final int BOARD_W_IN_PX = NUM_COLS * BOX_SIZE;
final int BOARD_H_IN_PX = NUM_ROWS * BOX_SIZE + (BOX_SIZE * 4);

int[][] grid = new int[NUM_COLS][NUM_ROWS];

float sideSpeed = 3f;
float dropSpeed = 0.5f;

Debugger debug;
Ticker dropTicker;
Ticker leftMoveTicker;
Ticker rightMoveTicker;

SoundManager soundManager;

// --- FEATURES ---
// kickback - If true, players can rotate pieces even if flush against wall.
//boolean allowInfiniteRotation = false;
//boolean allowChainReactions = false;
boolean allowKickBack= true;
boolean allowDrawingGhost = false;
boolean allowFadeEffect = false;

// Font stuff
SpriteFont nullTerminatorFont;

/*
 */
public void setup(){
  size(337, 464);
  
  // TODO: fix this
  //images[0] = loadImage("data/images/red.png");
  images[RED] = loadImage("data/images/red.png");
  images[ORANGE] = loadImage("data/images/orange.png");
  images[BLUE] = loadImage("data/images/blue.png");
  images[PINK] = loadImage("data/images/pink.png");
  images[GREEN] = loadImage("data/images/green.png");
  images[PURPLE] = loadImage("data/images/purple.png");
  images[BABYBLUE] = loadImage("data/images/babyblue.png");
  images[WHITE] = loadImage("data/images/babyblue.png");
  
  backgroundImg = loadImage("data/images/bk.png");
  nullTerminatorFont = new SpriteFont("data/fonts/null_terminator_2x.png", 14, 14, 2);
  
  debug = new Debugger();
  soundManager = new SoundManager(this);
  soundManager.init();
  soundManager.setMute(true);
  
  // Timers
  clearLineTicker = new Ticker();
  dropTicker = new Ticker();
  leftMoveTicker = new Ticker();
  rightMoveTicker = new Ticker();

  restartGame();
  
  // P = pause
  // G = ghost
  // F = fade
  // K = kickback
  // M = mute
  Keyboard.lockKeys(new int[]{KEY_P, KEY_G, KEY_F, KEY_K, KEY_M});
  
  // Assume the user wants kickback and muted
  Keyboard.setKeyDown(KEY_K, true);
  Keyboard.setKeyDown(KEY_M, true);
}

/*
 */
public void drawShape(Shape shape, int colPos, int rowPos){
  int[][] arr = shape.getArr();
  int shapeSize = shape.getSize();
    
  for(int c = 0; c < shapeSize; c++){
    for(int r = 0; r < shapeSize; r++){
      
      // Transposing here!
      if(arr[r][c] != 0){
        image( getImageFromID(shape.getColor()), (c * BOX_SIZE) + (colPos * BOX_SIZE), (r * BOX_SIZE) + (rowPos * BOX_SIZE));
      }
    }
  }
}

/*
 */
public Shape getRandomPiece(){
  int randInt = getRandomInt(0, 6);
  
  shapeStats[randInt]++;
  
  if(randInt == T_SHAPE) return new TShape();
  if(randInt == L_SHAPE) return new LShape();
  if(randInt == Z_SHAPE) return new ZShape();
  if(randInt == O_SHAPE) return new OShape();
  if(randInt == J_SHAPE) return new JShape();
  if(randInt == I_SHAPE) return new IShape();
  else                   return new SShape();
}

public void createPiece(){
  currentShape = (Shape)nextPieceQueue.popFront(); 
  
  currShapeRow = 0;
  currShapeCol = NUM_COLS/2;
  
  nextPieceQueue.pushBack(getRandomPiece());
}

/**
 */
public void clearGrid(){
  for(int c = 0; c < NUM_COLS; c++){
    for(int r = 0; r < NUM_ROWS; r++){
      grid[c][r] = EMPTY;
    }
  }
}

/*
 */
public void createBorders(){
  for(int col = 0; col < NUM_COLS; col++){
    grid[col][NUM_ROWS - 1] = WHITE;
  }
  
  for(int row = 0; row < NUM_ROWS; row++){
    grid[0][row] = WHITE;
  }

  for(int row = 0; row < NUM_ROWS; row++){
    grid[NUM_COLS-1][row] = WHITE;
  }
}

/* Start from the position of the current shape and 
 * keep going down until we find a collision.
 */
public void findGhostPiecePosition(){
  //
  //if(allowDrawingGhost == false){
  //  return;
  //}
  
  ghostShapeCol = currShapeCol;
  ghostShapeRow = currShapeRow;
  
  // If we move the shape down one row and it will not result in a collision, 
  // we can safely move the ghost piece row.
  while(checkShapeCollision(currentShape, ghostShapeCol, ghostShapeRow + 1) == false){
    ghostShapeRow++;
  }
}

/*
 */
public void drawBackground(){
  pushStyle();
  noFill();
  strokeWeight(1);
  stroke(255, 16);
  
  // Draw a translucent grid
  for(int cols = 0; cols < NUM_COLS; cols++){
    for(int rows = CUT_OFF_INDEX; rows < NUM_ROWS; rows++){
      rect(cols * BOX_SIZE, rows * BOX_SIZE, BOX_SIZE, BOX_SIZE);
    }
  }
  popStyle();
}

/*
 */
public boolean checkShapeCollision(Shape shape, int shapeCol, int shapeRow){
  int[][] arr = shape.getArr();
  int shapeSize = shape.getSize();
  
  // Iterate over the shape
  for(int c = 0; c < shapeSize; c++){
    for(int r = 0; r < shapeSize; r++){
     
      // An IShape could trigger an out of bounds exception.
      if(shapeCol + c >= NUM_COLS){
        continue;
      }
      
      if(shapeCol + c < 0){
        continue;
      }

      if(shapeRow + r >= NUM_ROWS){
        continue;
      }
      
      // Shape starts out out of the grid bounds.
      if(shapeRow + r < 0){
        continue;
      }
   
      // Transposed here!
      if(grid[shapeCol + c][shapeRow + r] != EMPTY && arr[r][c] != EMPTY){
        return true;
      }
    }
  }
  
  return false;
}


/**
 * Try to move a shape left or right. Use -ve values to move it left
 * and +ve values to move it right.
 */
public void moveSideways(int amt){
  currShapeCol += amt;
  
  if(checkShapeCollision(currentShape, currShapeCol, currShapeRow)){
    currShapeCol -= amt;
  }
}
    
/*
 */
public void update(){
  
  dropSpeed =  Keyboard.isKeyDown(KEY_DOWN)  ? 0.001f : 0.5f;
  sideSpeed =  Keyboard.isKeyDown(KEY_LEFT) ||  Keyboard.isKeyDown(KEY_RIGHT) ? 0.08f : 0f;
  
  // Features
  allowFadeEffect   = Keyboard.isKeyDown(KEY_F);
  allowKickBack     = Keyboard.isKeyDown(KEY_K);
  allowDrawingGhost = Keyboard.isKeyDown(KEY_G);
    
  dropTicker.tick();
  
  if(dropTicker.getTotalTime() >= dropSpeed){
    dropTicker.reset();
    
    if(currentShape != null){
      
      // If moving the current piece down one row results in a collision, we can add it to the board
      if(checkShapeCollision(currentShape, currShapeCol, currShapeRow + 1)){
        addPieceToBoard(currentShape);
      }
      else{
        currShapeRow++;
      }
    }
  }
  

  
  if(Keyboard.isKeyDown(KEY_LEFT) && Keyboard.isKeyDown(KEY_RIGHT)){
    rightMoveTicker.reset();
  }
  
  // If the player just let go of the left key, but they were holding it down, make sure not
  // to move and extra bit that the tap key condition would hit.
  else if(Keyboard.isKeyDown(KEY_LEFT) == false && holdingDownLeft == true){
    holdingDownLeft = false;
    leftMoveTicker.reset();
    moveBuffer = 0f;
  }
  // If the key hit was a tap, nudge the piece one block
  else if(Keyboard.isKeyDown(KEY_LEFT) == false && moveBuffer > 0f){
    leftMoveTicker.reset();
    moveBuffer = 0;
    moveSideways(-1);
  }
  // If the user is holding down the left key
  else if( Keyboard.isKeyDown(KEY_LEFT) ){
    leftMoveTicker.tick();
    
    moveBuffer += leftMoveTicker.getDeltaSec() * blocksPerSecond;
     
    // If we passed the tap threshold
    if(leftMoveTicker.getTotalTime() >= 0.1f){
      holdingDownLeft = true;
      
      // Only alllow moving one block at a time to prevent the need to move
      // back if a collision occurred.
      if(moveBuffer > 1.0f){
        moveBuffer -= 1.0f;
        moveSideways(-1);
      }
    }
  }
  
    
  // If the player just let go of the right key, but they were holding it down, make sure not
  // to move and extra bit that the tap key condition would hit.
  else if( Keyboard.isKeyDown(KEY_RIGHT) == false && holdingDownRight == true){
    holdingDownRight = false;
    rightMoveTicker.reset();
    rightBuffer = 0f;
  }
  // If the key hit was a tap, nudge the piece one block
  else if(Keyboard.isKeyDown(KEY_RIGHT) == false && rightBuffer > 0f){
    rightMoveTicker.reset();
    rightBuffer = 0;
    moveSideways(1);
  }
  
  // If the user is holding down the right key
  else if( Keyboard.isKeyDown(KEY_RIGHT) ){
    rightMoveTicker.tick();
    rightBuffer += rightMoveTicker.getDeltaSec() * blocksPerSecond;
    
    // If we passed the tap threshold
    if(rightMoveTicker.getTotalTime() >= 0.12f){
      holdingDownRight = true;
      
      // Only alllow moving one block at a time to prevent the need to move
      // back if a collision occurred.
      if(rightBuffer > 1.0f){
        rightBuffer -= 1.0f;
        moveSideways(1);
      }
    }
  }
  
  findGhostPiecePosition();
  
  //debug.addString("----------------");
  /*debug.addString("F - Toggle Fade effect " + getOnStr(Keyboard.isKeyDown(KEY_F)));
  debug.addString("G - Toggle Ghost piece ");
  debug.addString("K - Toggle Kick back " + getOnStr(Keyboard.isKeyDown(KEY_K)));
  debug.addString("M - Mute " + getOnStr(Keyboard.isKeyDown(KEY_M)));
  debug.addString("P - Pause game");*/
}

public String getOnStr(boolean b){
  return b ? "(on)" : "(off)";
}

/*
* 
*/
public void addPieceToBoard(Shape shape){
  int[][] arr = shape.getArr();
  int shapeSize = shape.getSize();
  int col = shape.getColor();
  
  for(int c = 0; c < shapeSize; c++){
    for(int r = 0; r < shapeSize; r++){
      
      // Transposing here!
      if(arr[r][c] != EMPTY){
        grid[currShapeCol + c][currShapeRow + r] = col;
      }
    }
  }
  
  if(addedBoxInCutoff()){
    hasLostGame = true;
    return;
  }
  
  int numLinesToClear = getNumLinesToClear();
  
  // TODO: clean this
  switch(numLinesToClear){
    case 0: soundManager.playDropPieceSound(); break;
    case 1: scoreForThisLevel += 100;score += 100;break;
    case 2: scoreForThisLevel += 250;score += 250;break;
    case 3: scoreForThisLevel += 450;score += 450;break;
    case 4: soundManager.playClearLinesSound();scoreForThisLevel += 800;score += 800;break;
    default: break;
  }
  
  
  // play score sound
  //
  
  // increse score
  //
  
  
  //
  if(level < MAX_LEVELS - 1 && scoreForThisLevel >= scoreReqForNextLevel[level]){
    scoreForThisLevel = 0;
    level++;
  }
  
  removeFilledLines();
  
  createPiece();
}

/**
 * returns a value from 0 - 4
 */
public int getNumLinesToClear(){
  int numLinesToClear = 0;
  
  // Don't include the floor and we technically
  // don't need to include the cut off index.
  for(int row = LAST_ROW_INDEX; row > CUT_OFF_INDEX; row--){
    
    boolean lineFull = true;
    for(int col = 1; col < NUM_COLS - 1; col++){
      if(grid[col][row] == EMPTY){
        lineFull = false;
      }
    }
    
    if(lineFull){
      numLinesToClear++;
    }
  }
  
  return numLinesToClear;
}

/* Start from the bottom row. If we found a full line,
 * copy everythng from the row above that line to
 * the current one.
 */
public void removeFilledLines(){

  for(int row = LAST_ROW_INDEX; row > CUT_OFF_INDEX; row--){
    boolean isLineFull = true;
    for(int col = 1; col < NUM_COLS - 1; col++){
      if(grid[col][row] == EMPTY){
        isLineFull = false;
      }
    }
    
    if(isLineFull){
      moveBlocksDownAboveRow(row);
      clearingLines = true;
      
      // Start from the bottom again
      row = NUM_ROWS - 1;
    }
  }
}

/* This is separate from removeFilledLines to keep the code a bit more clear.
 * Move all the blocks that are above the given row down 1 block
 * @see removeFilledLines
 */
public void moveBlocksDownAboveRow(int row){
  // TODO: add bounds check
  if(row >= NUM_ROWS || row <= CUT_OFF_INDEX){
    return;
  }
  
  // Go from given row to top of the board.
  for(int r = row; r > CUT_OFF_INDEX; r--){
    for(int c = 1; c < NUM_COLS-1; c++){
      grid[c][r] = grid[c][r-1];
    }
  }
}

/** Immediately place the piece into the board.
 */
public void dropPiece(){
  boolean foundCollision = false;
  
  while(foundCollision == false){ 
    currShapeRow++;
    if(checkShapeCollision(currentShape, currShapeCol, currShapeRow)){
      currShapeRow--;
      addPieceToBoard(currentShape);
      foundCollision = true;
    }
  }
}

/* Inspects the board and checks if the player tried
 * to add a part of a piece in the cutoff row, they lose.
 */
public boolean addedBoxInCutoff(){
  for(int c = 1; c < NUM_COLS - 1; c++){
    if(grid[c][CUT_OFF_INDEX] != EMPTY){
      return true;
    }
  }
  return false;
}

/*
 */
public int getRandomInt(int minVal, int maxVal) {
  return (int)random(minVal, maxVal + 1);
}

/**
 */
public void draw(){
  
  if(hasLostGame && Keyboard.isKeyDown(KEY_R)){
    restartGame();
  }
  
  if(didDrawGameOver){
    return;
  }

  if(hasLostGame){
    showGameOver();
    return;
  }
  
  if(Keyboard.isKeyDown(KEY_P) ){
    showGamePaused();
    return;
  }
  
  
  
  update();
  
  if(clearingLines){
    clearLineTicker.tick();
    if(clearLineTicker.getTotalTime() < 0.5f){
      return;
    }
    else{
      clearLineTicker.reset();
      clearingLines = false;
    }
  }
    
  
  if(allowFadeEffect){
    pushStyle();
    fill(0, 32);
    noStroke();
    rect(0, 0, width, height);
    popStyle();  
  }
  else{
    background(0);
  }
  
  
  
  
  // Draw cutoff
  /*pushMatrix();
  translate(0, BOX_SIZE * 3);
  pushStyle();
  fill(45, 0, 0, 200);
  rect(0, 0, BOX_SIZE * NUM_COLS, BOX_SIZE);
  popStyle();
  popMatrix();*/
  
  pushMatrix();
  translate(10, BOX_SIZE * 4 -4);
  drawBoard();
  
  
  
  findGhostPiecePosition();
  drawGhostPiece();

  drawShape(currentShape, currShapeCol, currShapeRow);
  
  //drawBackground();
    popMatrix();
    
    
  image(backgroundImg, 0, 0);
  //drawBorders();
  
  pushMatrix();
  translate(-100, 200);
  drawNextShape();
  popMatrix();
    
  // Draw debugging stuff on top of everything else
  pushMatrix();
  translate(200, 40);
  pushStyle();
  stroke(255);
  debug.draw();
  popStyle();
  popMatrix();
  
  drawText(nullTerminatorFont, "LEVEL " + str(level+1), 150, 20);
  drawText(nullTerminatorFont, "SCORE " + str(score), 150, 40);
    
  debug.clear();
}

// Encapsulate
public int charCodeAt(char ch){
  return ch;
}

/**
 */
public void restartGame(){
  
  // We 'add' 1 to this before we render
  level = 0;
  scoreForThisLevel = 0;
  score = 0;
  hasLostGame = false;
  didDrawGameOver = false;
  
  shapeStats = new int[]{0, 0, 0, 0, 0, 0, 0};
  
  clearGrid();
  createBorders();

  // It would be strange if the next pieces always stuck
  // around from end of one game to the start of the next.
  nextPieceQueue = new Queue();
  for(int i = 0; i < 3; i++){
    nextPieceQueue.pushBack(getRandomPiece());
  }
  
  createPiece();
}

/**
  * TODO: fix me
 */
public void drawText(SpriteFont font, String text, int x, int y){
  
  for(int i = 0; i < text.length(); i++){
    PImage charToPrint = font.getChar(text.charAt(i));
    image(charToPrint, x, y);
    x += font.getCharWidth() + 2;
  }
}

/**
 */
public void drawNextShape(){
  Shape nextShape = (Shape)nextPieceQueue.peekFront();
  drawShape(nextShape, 20, 0);
}

/* A ghost piece shows where the piece the user
 * is currently holding will end up.
 */
public void drawGhostPiece(){
  if(allowDrawingGhost == false){
    return;
  }
  
  //pushStyle();
  //color col = getColorFromID(currentShape.getColor());
  //float opacity = (ghostShapeRow - currShapeRow) / (float)NUM_ROWS * 32;
  //fill(col, opacity);
  //stroke(col, opacity * 5); 
  drawShape(currentShape, ghostShapeCol, ghostShapeRow);
  //popStyle();
}

public PImage getImageFromID(int col){
  return images[col];
}

/*
 * Rotating the shape may fail if rotating the shape results in
 * a collision with another piece on the board.
 */
public void requestRotatePiece(){
  
  // We try to rotate the shape, if it fails, we undo the rotation.
  currentShape.rotate();
      
  //
  //
  //
  int pos = currShapeCol;  
  int size = currentShape.getSize();
  int emptyRightSpaces = currentShape.getEmptySpacesOnRight();
  int emptyLeftSpaces = currentShape.getEmptySpacesOnLeft();
  
  int amountToShiftLeft = pos + size - emptyRightSpaces - (NUM_COLS-1);
  int amountToShiftRight = 1 - (pos - emptyLeftSpaces);
  
  if(DEBUG){
    println("pos: " + pos);
    println("amountToShiftLeft: " + amountToShiftLeft);
    println("amountToShiftRight: " + amountToShiftRight);
    println("emptyLeftSpaces: " + emptyLeftSpaces);
  }
  
  // If we are allowing the user to rotate the piece, even
  // if the piece is flush against the wall. 
  if(allowKickBack){
    // TODO: fix this hack
    // If one part of the piece is touching the right border
    if(amountToShiftRight > 0 && pos <= 0){
      currShapeCol += amountToShiftRight;
  
      // If the shape is still colliding (maybe from hitting somehtnig on the left side of the shape
      if(checkShapeCollision(currentShape, currShapeCol, currShapeRow)){
        currShapeCol -= amountToShiftRight;
      }
    }
    
    if(amountToShiftLeft > 0 ){
      currShapeCol -= amountToShiftLeft;
  
      // If the shape is still colliding (maybe from hitting somehtnig on the left side of the shape
      if(checkShapeCollision(currentShape, currShapeCol, currShapeRow)){
        currShapeCol += amountToShiftLeft;
      }
    }
  }
    
  if(checkShapeCollision(currentShape, currShapeCol, currShapeRow)){
    currentShape.unRotate();
  }
}

/*
 */
public void keyPressed(){
  
  if(keyCode == KEY_UP){
    requestRotatePiece();
  }
  
  Keyboard.setKeyDown(keyCode, true);
}

public void keyReleased(){
 
  if(keyCode == KEY_SPACE){
    dropPiece();
  }
  
  Keyboard.setKeyDown(keyCode, false);
}

/**
 * Iterate from 1 to NUM_COLS-1 because we don't want to draw the borders.
 * Same goes for not drawing the last row.
 */
public void drawBoard(){
  for(int cols = 1; cols < NUM_COLS-1; cols++){
    for(int rows = 0; rows < NUM_ROWS-1; rows++){
      drawBox(cols, rows, grid[cols][rows]);
    }
  }
}

/* Draw the board borders
 */
public void drawBorders(){
  pushStyle();
  noStroke();
  fill(256, 256, 256);
  
  // Floor
  for(int col = 0; col < NUM_COLS; col++){
    rect(col * BOX_SIZE, (NUM_ROWS-1) * BOX_SIZE, BOX_SIZE, BOX_SIZE);
  }
  
  for(int row = 2; row < NUM_ROWS; row++){
    rect(0, row * BOX_SIZE, BOX_SIZE, BOX_SIZE);
  }

  for(int row = 2; row < NUM_ROWS; row++){
    rect((NUM_COLS-1) * BOX_SIZE, row * BOX_SIZE, BOX_SIZE, BOX_SIZE);
  }
  popStyle();
}

/*
 *
 */
public void drawBox(int col, int row, int _color){
  if(_color != EMPTY){
    image(getImageFromID(_color), col * BOX_SIZE, row * BOX_SIZE);
  }
}

/*
 */
public void showGamePaused(){
  pushStyle();
  fill(128, 0, 0);
  noStroke();
  rect(0, BOX_SIZE * 3, width - 200, height);
  popStyle();
  
  drawText(nullTerminatorFont, "PAUSED", width/2 - (5 * 16)/2, 30);
}

/*
 * Overlay a semi-transparent layer on top of the board to hint
 * the game is no longer playable.
 */
public void showGameOver(){
  pushStyle();
  fill(128, 128);
  noStroke();
  rect(0, 0, width, height);
  popStyle();
  
  drawText(nullTerminatorFont, "GAME OVER", width/2 - (9 * 16)/2, 50);
  
  didDrawGameOver = true;
}
