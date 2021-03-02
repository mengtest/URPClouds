using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VolumeTextureGenerator : MonoBehaviour
{
    GameObject controlCameraObject;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    // Camera CreateCamera()
    // {

    // }

    void OnDrawGizmos()
    {
        Gizmos.color = Color.green;
        Gizmos.DrawWireCube(transform.position, transform.localScale);
    }
}
