# ========================================================
# SETUP
# ========================================================

# Clear the workspace
rm(list = ls())

# Load necessary libraries
require(here)
require(tidyverse)
require(dplyr)
require(ChoiceModelR)
require(onewaytests)
require(stringr)
require(writexl)


# Load the dataset
data <- read.csv(here("dataset", "CBC_Choices.csv"), sep = ";") 


# ========================================================
# DATA PREPROCESSING
# ========================================================

# Renaming columns
# -------------------------------------------------------

# Rename columns for clarity
data <- data %>% rename(resp.id = sys_RespNum,
                        alt = Concept,
                        choice = Response)


# Create Dummy Variables
# -------------------------------------------------------

# Recode all columns starting with "Attribute", this will easy readability of dummies later on
data <- data %>%
  mutate_at(vars(starts_with("Attribute")), list(~ recode(., `1` = "_low", `2` = "_medium", `3` = "_high")))

# List of attribute columns
attribute_cols <- grep("^Attribute", names(data), value = TRUE)

# Create dummy variables for each attribute
dummy_vars_list <- lapply(attribute_cols, function(col_name) {
  formula <- as.formula(paste("~", col_name, "- 1"))
  dummy_vars <- model.matrix(formula, data = data)
  colnames(dummy_vars) <- gsub(" ", ".", colnames(dummy_vars))  # Replace spaces with dots in column names
  return(dummy_vars)
})

# Combine dummy variables into a single data frame
dummy_vars_df <- do.call(cbind, dummy_vars_list)

# Add dummy variables to the original data frame
data <- cbind(data, dummy_vars_df)


# Create a choice variable based on alt and choice columns
# -------------------------------------------------------

# for every task, the row containing alternative 1 must hold the value that indicates which alternative was chosen, all other rows = 0
# if alternative 2 was chosen in task 1, 
# first row would indicate task:1 , alt:1, choice: 2
# second row would indicate task:1 , alt:2, choice: 0
choice <- rep(0, nrow(data))
choice[data[,"alt"] == 1] <- data[data[,"choice"] == 1, "alt"]

# Combine specified columns with dummy_vars_df
choice_data <- cbind(data[c("resp.id", "Task", "alt")], dummy_vars_df, choice)


# ========================================================
# DATA ANALYSIS
# ========================================================

# Remove columns ending with "medium", they will serve as reference groups and to avoid multicollinearity
choice_data <- choice_data %>% select(-ends_with("medium"))

# Check and create a folder if it doesn't exist to store the results of our estimation
if (!dir.exists(here("estimations"))) {
  dir.create(here("estimations"), recursive = TRUE)
}

# Perform choice modeling
hb.post <- choicemodelr(data = choice_data, 
                        xcoding = rep(1, 8),
                        mcmc = list(R = 20000, use = 10000),
                        options = list(save = T),
                        directory = here("estimations")
)


# ========================================================
# RECREATING SAWTOOTH/LIGHTHOUSE REPORT
# ========================================================

# Sheet:  Individual Utilities (Raw)
# -------------------------------------------------------

# Read in raw utilities and root-likelihood (RLH) estimated in previous step, merge by ID
individual_utilities_raw <- left_join(read.csv(here("estimations","RBetas.csv")), read.csv(here("estimations","RLH.csv")), "ID")

# Rename columns by matching names to our input dataframe
# Step 1: Get all columns that start with "Attribute" in choice_data
attribute_cols_df1 <- grep("^Attribute", names(choice_data), value = TRUE)

# Step 2: Get all columns that start with "A" in choice_data
cols_df2 <- grep("^A", names(individual_utilities_raw), value = TRUE)

# Step 3: Create a mapping between columns in choice_data and individual_utilities_raw based on their order
col_mapping <- setNames(cols_df2, attribute_cols_df1)

# Step 4: Rename columns in individual_utilities_raw using the mapping
individual_utilities_raw <- rename(individual_utilities_raw, !!!col_mapping)

# Step 5: Since we excluded "our "medium" as our reference group we need to add it back in
# Specify the column names you want to create
columns_to_create <- paste0("Attribute", 1:4, "_medium")

# Use a loop to create and set the columns
for (col_name in columns_to_create) {
  individual_utilities_raw[[col_name]] <- .0
}

# Add the number of parameters
individual_utilities_raw$Num_Parameters <- rep(12, nrow(individual_utilities_raw))

# Sort columns in desired order
individual_utilities_raw <- individual_utilities_raw %>%
  rename(Respondent = ID) %>%
  dplyr::select(
    "Respondent",
    "RLH",
    "Num_Parameters",
    "Attribute1_low",	
    "Attribute1_medium",
    "Attribute1_high",
    "Attribute2_low",
    "Attribute2_medium",
    "Attribute2_high",
    "Attribute3_low",
    "Attribute3_medium",
    "Attribute3_high",
    "Attribute4_low",
    "Attribute4_medium",
    "Attribute4_high"
  )



# Sheet:  Individual Importances
# -------------------------------------------------------

# Calculate attribute ranges for all attributes
individual_utilities_raw <- individual_utilities_raw %>%
  rowwise() %>%
  mutate(
    Attribute1_range = max(Attribute1_low, Attribute1_medium, Attribute1_high) - min(Attribute1_low, Attribute1_medium, Attribute1_high),
    Attribute2_range = max(Attribute2_low, Attribute2_medium, Attribute2_high) - min(Attribute2_low, Attribute2_medium, Attribute2_high),
    Attribute3_range = max(Attribute3_low, Attribute3_medium, Attribute3_high) - min(Attribute3_low, Attribute3_medium, Attribute3_high),
    Attribute4_range = max(Attribute4_low, Attribute4_medium, Attribute4_high) - min(Attribute4_low, Attribute4_medium, Attribute4_high)
  ) %>%
  mutate(
    Total_Attribute_range = sum(Attribute1_range, Attribute2_range, Attribute3_range, Attribute4_range)
  )


# Calculate importances for all attributes
individual_importances <- individual_utilities_raw %>%
  mutate(across(ends_with("range"), list(
    importance = ~ .x / Total_Attribute_range * 100
  )))


# Select the respondent and importance columns, remove rest
individual_importances <- individual_importances %>%
  select(Respondent, ends_with("range_importance"))

# Removing _range_ from colum names
individual_importances <- individual_importances %>%
  rename_all(~ str_replace_all(., "_range_", "_"))



# Sheet:  Summary - Average Importances
# -------------------------------------------------------

# Calculate summary statistics (Mean and SD) for importance values of attributes
individual_importances_summary <- individual_importances %>%
  ungroup() %>%
  summarize(
    across(starts_with("Attribute"), list(
      Mean = ~ mean(.x),
      SD = ~ sd(.x)
    ), .names = "{.col}_{.fn}")
  )

## Average importances 
# Calculate the average importances for each attribute using across and summarise
average_importances <- individual_importances_summary %>%
  summarise(
    # Use across to select columns that start with "Attribute" and calculate mean for each
    across(ends_with("_Mean"), ~ mean(.))
  )


# Transpose the average_importances data frame
average_importances <- as.data.frame(t(average_importances))

# Add a "Variable" column with row names
average_importances <- cbind(Variable = rownames(average_importances), average_importances)

# Reset row names to be sequential numbers
rownames(average_importances) <- 1:nrow(average_importances)

# Rename the second column to "Average Importances"
colnames(average_importances)[2] <- "Average Importances"

# Remove the "_importance_Mean" suffix from Variable
average_importances$Variable <- gsub("_importance_Mean$", "", average_importances$Variable)


## Standard Deviation
# Calculate the standard deviation for each attribute using across and summarise
standard_deviation <- individual_importances_summary %>%
  summarise(
    # Use across to select columns that start with "Attribute" and calculate mean for each
    across(ends_with("_SD"), ~ mean(.))
  )


# Transpose the standard_deviation data frame
standard_deviation <- as.data.frame(t(standard_deviation))

# Add a "Variable" column with row names
standard_deviation <- cbind(Variable = rownames(standard_deviation), standard_deviation)

# Reset row names to sequential numbers
rownames(standard_deviation) <- 1:nrow(standard_deviation)

# Rename the second column to "Standard Deviation"
colnames(standard_deviation)[2] <- "Standard Deviation"

# Remove the "_importance_Mean" suffix from Variable
standard_deviation$Variable <- gsub("_importance_SD$", "", standard_deviation$Variable)


# Join both dfs together
final.importances <- left_join(average_importances, standard_deviation, by="Variable")



# Sheet:  Individual Utilities (ZC Diffs)
# -------------------------------------------------------

#### Calcualte Zero-Centered Diffs from raw betas based on dummy coding ####
### Formula: https://community.sawtoothsoftware.com/lighthouse-studio/post/is-there-a-formula-for-calculating-the-zero-centered-diffs-pMt4EAIEEK2GA8k ###
# Select all attributes and respondent ids
individual_utilities_zc <- individual_utilities_raw %>%
  select(Respondent,
         ends_with(c("_low",
                     "_medium",
                     "_high"))) %>%
  as.data.frame()

# Step 1.1: Within each attribute, compute the mean utility. 
individual_utilities_zc <- individual_utilities_zc %>%
  mutate(Mean_Attribute1 = rowMeans(select(.,c("Attribute1_low","Attribute1_medium","Attribute1_high"))),
         Mean_Attribute2 = rowMeans(select(.,c("Attribute2_low","Attribute2_medium","Attribute2_high"))),
         Mean_Attribute3 = rowMeans(select(.,c("Attribute3_low","Attribute3_medium","Attribute3_high"))),
         Mean_Attribute4 = rowMeans(select(.,c("Attribute4_low","Attribute4_medium","Attribute4_high")))
  )

# Step 1.2: Within each attribute, subtract the mean utility from each utility 
individual_utilities_zc <- individual_utilities_zc %>%
  mutate(
    Attribute1_low_meanadj = Attribute1_low - Mean_Attribute1,
    Attribute1_medium_meanadj = Attribute1_medium - Mean_Attribute1,
    Attribute1_high_meanadj = Attribute1_high - Mean_Attribute1,
    
    Attribute2_low_meanadj = Attribute2_low - Mean_Attribute2,
    Attribute2_medium_meanadj = Attribute2_medium - Mean_Attribute2,
    Attribute2_high_meanadj = Attribute2_high - Mean_Attribute2,
    
    Attribute3_low_meanadj = Attribute3_low - Mean_Attribute3,
    Attribute3_medium_meanadj = Attribute3_medium - Mean_Attribute3,
    Attribute3_high_meanadj = Attribute3_high - Mean_Attribute3,
    
    Attribute4_low_meanadj = Attribute4_low - Mean_Attribute4,
    Attribute4_medium_meanadj = Attribute4_medium - Mean_Attribute4,
    Attribute4_high_meanadj = Attribute4_high - Mean_Attribute4
  )


# Step 2.1: For each attribute compute the difference between best and worst utilities.
individual_utilities_zc <- individual_utilities_zc %>%
  mutate(Attribute1_range = pmax(Attribute1_low_meanadj,Attribute1_medium_meanadj,Attribute1_high_meanadj)-pmin(Attribute1_low_meanadj,Attribute1_medium_meanadj,Attribute1_high_meanadj),
         Attribute2_range = pmax(Attribute2_low_meanadj,Attribute2_medium_meanadj,Attribute2_high_meanadj)-pmin(Attribute2_low_meanadj,Attribute2_medium_meanadj,Attribute2_high_meanadj),
         Attribute3_range = pmax(Attribute3_low_meanadj,Attribute3_medium_meanadj,Attribute3_high_meanadj)-pmin(Attribute3_low_meanadj,Attribute3_medium_meanadj,Attribute3_high_meanadj),
         Attribute4_range = pmax(Attribute4_low_meanadj,Attribute4_medium_meanadj,Attribute4_high_meanadj)-pmin(Attribute4_low_meanadj,Attribute4_medium_meanadj,Attribute4_high_meanadj)
  )

# Step 2.2: Sum those across attributes.
individual_utilities_zc <- individual_utilities_zc %>%
  mutate(Total_range_sum = rowSums(select(.,c("Attribute1_range","Attribute2_range","Attribute3_range","Attribute4_range")))
  )

# Step 3: Take 100 x number of attributes (here: 4) and divide it by the sum achieved in step 2.  This is a single multiplier that you use in step 4
individual_utilities_zc <- individual_utilities_zc %>%
  mutate(Multiplier = 100*4/Total_range_sum
  )

# Step 4: Multiply all utilities from step 1 by the multiplier.  Now, the average difference between best and worst utilities per attribute is 100 utility points.
individual_utilities_zc <- individual_utilities_zc %>%
  mutate(
    Attribute1_low_zcdiffs = Attribute1_low_meanadj*Multiplier,
    Attribute1_medium_zcdiffs = Attribute1_medium_meanadj*Multiplier,
    Attribute1_high_zcdiffs = Attribute1_high_meanadj*Multiplier,
    
    Attribute2_low_zcdiffs = Attribute2_low_meanadj*Multiplier,
    Attribute2_medium_zcdiffs = Attribute2_medium_meanadj*Multiplier,
    Attribute2_high_zcdiffs = Attribute2_high_meanadj*Multiplier,
    
    Attribute3_low_zcdiffs = Attribute3_low_meanadj*Multiplier,
    Attribute3_medium_zcdiffs = Attribute3_medium_meanadj*Multiplier,
    Attribute3_high_zcdiffs = Attribute3_high_meanadj*Multiplier,
    
    Attribute4_low_zcdiffs = Attribute4_low_meanadj*Multiplier,
    Attribute4_medium_zcdiffs = Attribute4_medium_meanadj*Multiplier,
    Attribute4_high_zcdiffs = Attribute4_high_meanadj*Multiplier
  )



# Add respondent id and RLHs from rasw utilities back to zero-centered utilities
individual_utilities_zc <- left_join(individual_utilities_zc,
                                     individual_utilities_raw %>% select(Respondent, RLH), 
                                     "Respondent")

# Sort columns
individual_utilities_zcdiffs <- individual_utilities_zc %>%
  dplyr::select(
    Respondent,
    RLH,
    ends_with("_zcdiffs")
  )



# Sheet:  Summary - Average Utilitites (Zero-Centered Diffs)
# -------------------------------------------------------

## Part 1: Average utilites
# Calculate mean for each attribute and level
average_utilities_zcdiffs <- individual_utilities_zcdiffs %>%
  summarise(
    across(ends_with("_low_zcdiffs"), list(mean = mean)),
    across(ends_with("_medium_zcdiffs"), list(mean = mean)),
    across(ends_with("_high_zcdiffs"), list(mean = mean))
  )

# Transpose the data frame and add a 'Attribute_Level' column
average_utilities_zcdiffs <- as.data.frame(t(average_utilities_zcdiffs))
average_utilities_zcdiffs <- cbind(Attribute_Level = rownames(average_utilities_zcdiffs), average_utilities_zcdiffs)
rownames(average_utilities_zcdiffs) <- 1:nrow(average_utilities_zcdiffs)

# Rename column names
colnames(average_utilities_zcdiffs)[2]<- "Average Utilities"

# Remove "_mean" from the 'Attribute_Level' column
average_utilities_zcdiffs$Attribute_Level <- gsub("_mean", "", average_utilities_zcdiffs$Attribute_Level)


## Part 2: Standard deviation (SD)
# Calculate SD for each attribute and level
average_utilities_zcdiffs_sds <-  individual_utilities_zcdiffs %>%
  summarise(
    across(ends_with("_low_zcdiffs"), list(sd = sd)),
    across(ends_with("_medium_zcdiffs"), list(sd = sd)),
    across(ends_with("_high_zcdiffs"), list(sd = sd))
  )

# Transpose the data frame and add a 'Attribute_Level' column
average_utilities_zcdiffs_sds <- as.data.frame(t(average_utilities_zcdiffs_sds))
average_utilities_zcdiffs_sds <- cbind(Attribute_Level = rownames(average_utilities_zcdiffs_sds), average_utilities_zcdiffs_sds)
rownames(average_utilities_zcdiffs_sds) <- 1:nrow(average_utilities_zcdiffs_sds)

# Rename column names
colnames(average_utilities_zcdiffs_sds)[2]<- "Standard Deviation"

# Remove "_sd" from the 'Attribute_Level' column
average_utilities_zcdiffs_sds$Attribute_Level <- gsub("_sd", "", average_utilities_zcdiffs_sds$Attribute_Level)


# Merge average utilities and standard deviations to one data frame
final.average.utilities_zcdiffs <- left_join(average_utilities_zcdiffs, 
                                             average_utilities_zcdiffs_sds, 
                                             by="Attribute_Level")

# Sort rows
final.average.utilities_zcdiffs <- final.average.utilities_zcdiffs %>%
  arrange(
    substr(Attribute_Level, 1, 10),  # Sort by the first 10 characters (Attribute1, Attribute2, etc.)
    substr(Attribute_Level, nchar(Attribute_Level) - 2, nchar(Attribute_Level))  # Sort by the last 3 characters (low, medium, high)
  )


# Rename Attribute_Level to Average Utilities (Zero-Centered Diffs)
rename(final.average.utilities_zcdiffs, `Average Utilities (Zero-Centered Diffs)` = Attribute_Level)



# Export Final Report (incl all sheets)
# -------------------------------------------------------
# Check and create a folder if it doesn't exist to store our report
if (!dir.exists(here("report"))) {
  dir.create(here("report"), recursive = TRUE)
}

# Remove old report:
if (file.exists(here("report","HB_report.xlsx"))) {
  file.remove(here("report","HB_report.xlsx"))
}


# Export into one single xlsx
write_xlsx(list(
  `Summ - Average Importances`= final.importances,
  `Summ - Avg. Util. (ZC Diffs)` = final.average.utilities_zcdiffs,
  `Individual Utilities (Raw)` = individual_utilities_raw,
  `Individual Util.s (ZC Diffs)` = individual_utilities_zcdiffs,
  `Individual Importances` = individual_importances), 
  path = here("report","HB_report.xlsx"))
