# Hierarchical Bayesian logistic regression analysis in R 
This README provides detailed instructions on how to use the provided R code for conducting a hierarchical Bayesion logistic regression using choice-based conjoint data, as well as recreating a corresponding Sawtooth/Lighthouse report to summarize the results. 
The code is designed for students or researchers who want to analyze choice data and generate useful reports. 
Please follow the steps outlined below to successfully use the code.

## Table of Contents
1. [Setup](#setup)
2. [Data Preprocessing](#data-preprocessing)
3. [Data Analysis](#data-analysis)
4. [Recreating Sawtooth/Lighthouse Report](#recreating-sawtoothlighthouse-report)
5. [Exporting Final Report](#exporting-final-report)

## 1. Setup <a name="setup"></a>

### Required Libraries
Before running the code, ensure you have the necessary R packages installed. You can install these packages using the `install.packages()` function if you haven't already.

```R
require(here)
require(tidyverse)
require(dplyr)
require(ChoiceModelR)
require(onewaytests)
require(stringr)
require(writexl)
```

### Load the Dataset
Make sure you have your choice dataset prepared in a CSV file format. The code assumes that your dataset is stored in a folder named "dataset" and the file is named "CBC_Choices.csv". You can modify the file path accordingly.

```R
# Load the dataset
data <- read.csv(here("dataset", "CBC_Choices.csv"), sep = ";") 
```

![alt text](https://github.com/MyNameIsCarsten/beatstars-upload/blob/main/GUI.jpg)

## 2. Data Preprocessing <a name="data-preprocessing"></a>

### Renaming Columns
Columns are renamed for clarity to match specific variable names. This step is necessary to ensure uniformity in the dataset.

### Creating Dummy Variables
The code creates dummy variables for categorical attributes to prepare the data for choice modeling. It renames these dummy variables by replacing spaces with dots in column names.

### Creating a Choice Variable
A choice variable is created based on the "alt" (alternative) and "choice" columns. This variable indicates which alternative was chosen for each task.

## 3. Data Analysis <a name="data-analysis"></a>

### Removing Medium Columns
Columns ending with "medium" are removed to serve as reference groups and avoid multicollinearity.

### Performing Choice Modeling
Choice modeling is performed using the `choicemodelr` function. The results will be saved in the "HB_r" directory.

## 4. Recreating Sawtooth/Lighthouse Report <a name="recreating-sawtoothlighthouse-report"></a>

### Individual Utilities (Raw)
This section reads in raw utilities and root-likelihood (RLH) estimates and renames columns to match the input dataframe.

### Individual Importances
This section calculates attribute ranges and importances for all attributes based on raw utilities.

### Summary - Average Importances
Calculates average importances and standard deviations for each attribute.

### Individual Utilities (ZC Diffs)
Calculates Zero-Centered Diffs from raw betas based on dummy coding.

### Summary - Average Utilities (Zero-Centered Diffs)
Calculates the mean and standard deviation of utilities for each attribute level.

## 5. Exporting Final Report <a name="exporting-final-report"></a>

The final report is exported as an Excel file named "HB_report.xlsx". It includes sheets for the following:
- `Summ - Average Importances`: Summary of average importances.
- `Summ - Avg. Util. (ZC Diffs)`: Summary of average utilities with Zero-Centered Diffs.
- `Individual Utilities (Raw)`: Individual-level utilities.
- `Individual Util.s (ZC Diffs)`: Individual-level utilities with Zero-Centered Diffs.
- `Individual Importances`: Individual-level importances.

## Running the Code
1. Ensure you have R and RStudio installed on your computer.
2. Install the required R packages mentioned in the "Required Libraries" section if you haven't already.
3. Prepare your choice dataset in CSV format and place it in a folder named "dataset" with the file name "CBC_Choices.csv", or modify the file path accordingly.
4. Copy and paste the provided code into an R script or RStudio.
5. Run the code step by step, ensuring each section executes without errors.
6. After running all sections, you will find the final report "HB_report.xlsx" in the "HB_r" directory.

Note: Be patient when running the code, as choice modeling and data processing can take some time depending on the dataset's size and complexity.