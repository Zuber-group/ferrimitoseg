
// === Base directory and pixel size ===
baseDir = "D:/Khosorzadeh_Amin/Ferritin_label_times/";
baseline_pixel_size = 0.00042720;

// === Init CLIJ2 ===
run("CLIJ2 Macro Extensions", "cl_device=[Quadro RTX 5000]");

// === Loop through datasets ===
folderList = getFileList(baseDir);
for (i = 0; i < folderList.length; i++) {
    currentFolder = baseDir + folderList[i];
    if (File.isDirectory(currentFolder)) {

        // Create output folders
        denoised_dir = currentFolder + "/denoised/";
        filtered_dir = currentFolder + "/filtered/";
        detected_dir = currentFolder + "/detected/";
        fretin_dir   = currentFolder + "/fretin/";
        File.makeDirectory(denoised_dir);
        File.makeDirectory(filtered_dir);
        File.makeDirectory(detected_dir);
        File.makeDirectory(fretin_dir);
        
        // Loop through TIFF files
        fileList = getFileList(currentFolder);
        for (j = 0; j < fileList.length; j++) {
            if (endsWith(fileList[j], ".tif")) {
                
                // Define paths
                input_path    = currentFolder + "/" + fileList[j];
                denoised_path = denoised_dir   + fileList[j];
                filtered_path = filtered_dir   + fileList[j];
                detected_path = detected_dir   + fileList[j];
                fretin_path   = fretin_dir     + fileList[j];
                
                // === Step 1: Open image & compute scale ===
                open(input_path);
                imageName = fileList[j];
                selectImage(imageName);
                getVoxelSize(pixelWidth, pixelHeight, pixelDepth, unit);
                scale = baseline_pixel_size / pixelWidth;
                sigma = 2.0;
                sigma_bg = 7.0 * scale;
                print("Processing " + imageName + " with pixel size: " + pixelWidth + " " + unit + " and scale: " + scale);
                
                // === Step 2: Denoise (Gaussian blur) ===
                Ext.CLIJ2_push(imageName);
                blurredName = "blur_" + imageName;
                Ext.CLIJ2_gaussianBlur2D(imageName, blurredName, sigma, sigma);
                Ext.CLIJ2_pull(blurredName);
                rename(blurredName);
                saveAs("Tiff", denoised_path);
                
                // === Step 3: Background division ===
                Ext.CLIJ2_push(blurredName);
                dividedName = "divided_" + imageName;
                Ext.CLIJ2_divideByGaussianBackground(blurredName, dividedName, sigma_bg, sigma_bg, sigma_bg);
                Ext.CLIJ2_pull(dividedName);
                rename(dividedName);
                saveAs("Tiff", filtered_path);
                
                // === Step 4: Invert ===
                run("Invert");
                
                // === Step 5: Exponential transform ===
                currentImage = getTitle();
                Ext.CLIJ2_push(currentImage);
                expName = "exp_" + imageName;
                Ext.CLIJ2_exponential(currentImage, expName);
                Ext.CLIJ2_pull(expName);
                rename(expName);
                saveAs("Tiff", detected_path);
                
                // === Step 6: Threshold ===
                getRawStatistics(nPixels, mean, min, max, stdDev, histogram);
                setMinAndMax(min, max);
                setAutoThreshold("Intermodes dark no-reset");
                setOption("BlackBackground", true);
                run("Convert to Mask");
                image_thresholded = getTitle();
                
                // === Step 7: Erode labels ===
                Ext.CLIJ2_push(image_thresholded);
                erodedName = "erode_labels_" + imageName;
                Ext.CLIJ2_erodeLabels(image_thresholded, erodedName, 2.0, false);
                Ext.CLIJ2_pull(erodedName);
                rename(erodedName);
		setOption("BlackBackground", true);
                
                // === Step 8: Dilate labels ===
                Ext.CLIJ2_push(erodedName);
                dilatedName = "dilate_labels_" + imageName;
                Ext.CLIJ2_dilateLabels(erodedName, dilatedName, 3.0);
                Ext.CLIJ2_pull(dilatedName);
                rename(dilatedName);
                saveAs("Tiff", fretin_path);
                
                // === Step 9: Re-threshold (optional) ===
                setAutoThreshold("Default dark no-reset");
                setOption("BlackBackground", true);
                run("Convert to Mask");
                finalMask = getTitle();
                
                // === Step 10: Analyze particles ===
                roiManager("Reset");
                run("Analyze Particles...", "size=10-500 circularity=0.50-1.00 display exclude add");
                
                // === Step 11: Save ROIs as image ===
                width = getWidth();
                height = getHeight();
                newImage("fretin_output", "8-bit black", width, height, 1);
                selectWindow("fretin_output");
                roiManager("Fill");
                saveAs("Tiff", fretin_path);
                
                // === Cleanup ===
                run("Close All");
                roiManager("Reset");
                print("✅ Done: " + imageName);
            }
        }
    }
}
