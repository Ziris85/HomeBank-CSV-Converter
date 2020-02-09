# HomeBank-CSV-Converter
For use with the opensource HomeBank personal accounting software: http://homebank.free.fr/. Their online documentation can be found [here](http://homebank.free.fr/help/index.html).

(Tested against **HomeBank v5.3.1**)

This is a perl script to convert a CSV file containing transactions from your banking institution into a HomeBank-friendly format.

This script does not attempt to make decisions for the user (with the exception of **autopay** - see below), does not require the user to create complex definition files to do the conversion process, nor does it only function with certain banking institutions. As long as your bank can export your transactions into a valid CSV format, then this script should be able to work with it.

Hope you like it!

## Methods
Results in either method are, by default, output to a file with the same name as the input file, with a **-homebank-exported** appended to it (so, if your banks filename is **Jan-2020-Transactions.csv**, the output filename would be **Jan-2020-Transactions-homebank-exported.csv**). This can be overridden in the manual method. If the destination file already exists, the script will warn the user and require confirmation to proceed.

### Interactive
By default if the script is only provided a CSV file, then it will enter into a guided, interactive mode. This mode will ask the user a series of questions and guide them through defining all of the columns in their CSV file to HomeBank-supported columns. Once all of the columns have been defined (or skipped, if they don't line up with equivalent HomeBank columns), then the script will process the conversion and output the results to the output file.

### Manual/Direct
The script can also be passed a series of arguments to automate the conversion process. If these arguments are provided, interactive mode is skipped and the script jumps straight to the conversion process with no user input requested. The arguments passed are column definitions, and optional adjustments to script defaults.
#### COLUMNS
Each of the columns that are passed as arguments must be defined with a number. This number corresponds to the column in the users CSV file that correlates with the HomeBank-equivalent column (numbers start at **0**, so the first column in the users CSV file would be column **0**). Not all columns need to be defined, and any that are not provided are simply entered with empty data on the output file.
| Column | Description |
| --- | --- |
| --date=# | Date of transaction |
| --payment=# | Payment type code |
| --info=# | A string |
| --payee=# | A payee name |
| --memo=# | A string (usually a description of the transaction) |
| --amount=# | A number with a '.' or ',' as decimal separator, ex: -24.12 or 36,75 |
| --category=# | A full category name (category, or category:subcategory) |
| --tags=# | Tags separated by space |

#### OPTIONS
These options simply tweak the default behavior of the script, if necessary (say, for example, if the CSV file uses a `|` for the separator instead of a `,`).
| Option | Description |
| --- | --- |
| --output=s | Name of file to output results to (default: <input_file_name> + -homebank-exported.csv) |
| --sep=s | Separator to your CSV file (default: ,) |
| --header=[Y\|n] | Specify whether your CSV file contains a header (defaut: n) |
| --autopay=[Y\|#] | Enable automatic detection of payment codes. This can also be defined as a code, in which case ALL transactions in your CSV will be marked with said code. |

#### Examples
Let us say that the users CSV file has a format like so:

```"Date";"Description";"Comments";"Check Number";"Amount";"Balance"```
 
Possible execution of the script with arguments could look like:

```./convert transactions.csv --date=0 --memo=1 --category=2 --info=3 --amount=4 --header=y --sep=;```

### Autopay
This is a rudimentary feature that was added to give the script a simple means of attempting to automatically detect the payment code of the transaction for the user. This feature is far from comprehensive, and mainly looks for obvious keywords (like **_fee_**). Autopay is disabled by default but can be used in both methods described above. When enabling this feature, the user may provide either a simple `y` to allow the script to work as just described, or they may provide a payment code - in which case, ALL transactions will be labeled with the same payment code. The payment codes are as follows:
| Code | Description |
| --- | --- |
| 0 | None |
| 1 | Credit Card |
| 2 | Check |
| 3 | Cash |
| 4 | Bank Transfer |
| 5 | Debit Card |
| 6 | Standing Order |
| 7 | Electronic Payment |
| 8 | Deposit |
| 9 | Fee |
| 10 | Direct Debit |

Use of this feature is generally _not recommended_, at least not on its own. It's recommended that the user either user this feature in conjunction with the **Automatic Assignment** feature [documented here](http://homebank.free.fr/help/use-auto_assign.html), or use **Automatic Assignment** exclusively, as it allows fine-grained control over categorization of transactions during import, and will likely generate better results tailored to the user.
