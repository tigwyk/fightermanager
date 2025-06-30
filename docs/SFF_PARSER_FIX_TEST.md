## SFF Parser Fix Test Results

Testing the fixed SFF parser with corrected header layout interpretation:

### Expected Results for KFM
- **Groups**: 2 (from position 24)
- **Images**: 281 (from position 40)  
- **Subheader offset**: 624 (from position 36)
- **Version**: 1.0

### Key Fix Applied
The SFF v1.0 header layout was misinterpreted. The correct interpretation based on hex analysis:

```
Position  Field               Value
0-11      Signature          "ElecbyteSpr\0"
12        Version Lo         1
13        Version Hi         0  
14-15     Reserved           [00, 02]
16-23     Reserved (8 bytes) [00 00 00 00 00 00 00 00]
24-27     Group Count        2
28-31     Reserved           0
32-35     Reserved           0
36-39     Subheader Offset   624
40-43     Image Count        281
44-47     Unknown            2
```

### Changes Made
1. Updated header parsing to read groups from position 24
2. Updated header parsing to read images from position 40
3. Updated header parsing to read subheader offset from position 36
4. Removed incorrect palette type reading 
5. Updated validation to accept reasonable sprite counts

### Test Command
Run the main menu scene - it will automatically test the SFF parser and show results in the console.

### Expected Outcome
- KFM SFF should now parse successfully
- Parser should report 2 groups and 281 images
- Character loading should proceed to sprite loading phase
- No more "0 groups and 0 images" error for KFM
