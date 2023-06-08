using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using System.Linq;

public class AutoCreateURPUnLit
{
    private static string UnlitShaderPath="";

    [MenuItem("Assets/Shader/URP_UnLit")]
    static void CreateUnLitShader()
    {
        var current = Selection.activeObject;
        var path = AssetDatabase.GetAssetPath(current);
        if(Path.HasExtension(path))
        {
            path = Directory.GetParent(path).FullName;
        }
        Shader shader = Shader.Find("Custom/Unlit");
        StreamReader sr = new StreamReader(Path.GetFullPath(AssetDatabase.GetAssetPath(shader)));
        List<string> shaderProgram =new List<string>();
        int index=0;
        while(!sr.EndOfStream)
        {
            string str = sr.ReadLine();
            shaderProgram.Add(str);
            Debug.Log(str);
            index++;
            if(index > 1000)
            {
                break;
            }
        }
        sr.Close();

        StreamWriter sw=new StreamWriter(path + "/Unlit.shader");
        foreach(string s in shaderProgram)
        {
            sw.WriteLine(s);
        }
        sw.Flush();
        sw.Close();
        // AssetDatabase.CreateAsset(shader,path);
        // AssetDatabase.Refresh();
        //StreamWriter sw = new StreamWriter(path);
        
    }
}
