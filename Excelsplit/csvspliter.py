import pandas as pd
import tkinter as tk
import os
from tkinter import filedialog
from tkinter import simpledialog
toproot = tk.Tk()
filepath = filedialog.askopenfilename( title = '请选择csv文件', filetypes=[("CSV files","*.CSV")],parent = toproot)
folderpath = filedialog.askdirectory( title = '请选择输出文件目录地址', parent = toproot )
entriesperfile = simpledialog.askinteger(title = '数据条目', prompt = '请输入每一个文件的数据条目数', parent = toproot)

if filepath != '' and folderpath != '' and entriesperfile != 0:
    targetfilename =  os.path.splitext(os.path.basename(filepath))[0]
    df = pd.read_csv(filepath,low_memory=False)
    filenum = 0
    prefilelen = 0
    while filenum == 0 or prefilelen > 0:
        beginline =  filenum * entriesperfile
        endline = ( filenum + 1 ) * entriesperfile
        df1 = df.iloc[beginline: endline]
        prefilelen = df1.index.size
        filenum = filenum + 1         
        if prefilelen > 0:
            str1 = folderpath + '\\' + targetfilename + str(filenum)  + ".csv"
            df1.to_csv(str1,index=False)
    tk.messagebox.showinfo(title='Excel拆分', message='数据拆分成功', parent = toproot)
else:
    tk.messagebox.showinfo(title='Excel拆分', message='数据拆分取消', parent = toproot)