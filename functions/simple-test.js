const fs = require('fs');
const path = require('path');

// Path to the test invoice image
const imagePath = path.resolve('./assets/test/invoice-test.png');
const alternativePath = path.resolve('../assets/test/invoice-test.png');

console.log("Checking image file:");
console.log("Direct path:", imagePath);
console.log("Alternative path:", alternativePath);

// Check if the file exists at either path
const directPathExists = fs.existsSync(imagePath);
const alternativePathExists = fs.existsSync(alternativePath);

console.log("File exists at direct path:", directPathExists);
console.log("File exists at alternative path:", alternativePathExists);

// Get file stats if available
const filePath = directPathExists ? imagePath : (alternativePathExists ? alternativePath : null);

if (filePath) {
  const stats = fs.statSync(filePath);
  console.log("\nFile information:");
  console.log("- Size:", stats.size, "bytes");
  console.log("- Created:", stats.birthtime);
  console.log("- Modified:", stats.mtime);
  
  // Read a small portion of the file to verify it's readable
  try {
    const fileHandle = fs.openSync(filePath, 'r');
    const buffer = Buffer.alloc(100);
    const bytesRead = fs.readSync(fileHandle, buffer, 0, 100, 0);
    fs.closeSync(fileHandle);
    
    console.log("\nSuccessfully read", bytesRead, "bytes from the file");
    console.log("File appears to be valid and accessible");
  } catch (error) {
    console.error("\nError reading from file:", error.message);
  }
} else {
  console.error("\nError: Invoice test image not found at either path");
} 