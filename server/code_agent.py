from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import ChatPromptTemplate
import re

class CodeAgent:
    def __init__(self, file_path):
        self.file_path = file_path
        self.model = ChatGoogleGenerativeAI(
                                model="gemini-1.5-flash",
                                temperature=0,
                                max_tokens=None,
                                timeout=None,
                                max_retries=2,
                       )
        
        self.code_generation_prompt = '''
            You are an AI assistant that generates valid .gltf files using the pygltflib library in Python based on the user question. Your task is to generate Python code that correctly creates a 3D box and exports it as a .gltf file along with a .bin file for binary data storage.


            Constraints & Requirements:

            Use Only Standard Python Libraries

            The only external libraries allowed are numpy and pandas.

            No other third-party dependencies should be used except pygltflib (which is required for .gltf creation). use only version 1.16.3.here is the documentation how to use pyglflib: https://gitlab.com/dodgyville/pygltflib

            Correctly Define Buffer, BufferViews, and Accessors

            Define vertices (position + normals) and indices correctly.

            Ensure accessors reference the correct buffer views.

            Use explicit byte offsets and ensure all data is properly aligned.

            Ensure Proper Face Winding Order

            Use counter-clockwise vertex ordering for correct face rendering.

            Avoid issues with backface culling.

            Add Vertex Normals

            Compute and store normals for each vertex.

            Reference normals properly in the GLTF format.

            Include URI Reference for the Buffer

            Store vertex and index data in a separate binary file (.bin) instead of embedding it in JSON.

            The .gltf file should reference this binary buffer properly.

            Ensure Proper Data Alignment and Compatibility

            Make sure the buffer size correctly matches the sum of vertices and indices data sizes.

            Avoid any mismatches that would cause GLTF parsers to reject the file.

            Output the Files (.gltf and .bin)

            Save a .gltf file containing references to the .bin file.

            The .bin file should store vertex and index data in binary format.

            Your response should provide a complete Python script that implements these requirements in a clean, structured, and well-commented manner.
            
            Here is example code for generating a cube in pygltflib:
            {example_code}
        '''
        
        self.example_code = '''
                        import numpy as np
            from pygltflib import (
                GLTF2, Buffer, BufferView, Accessor, Scene, Node, Mesh, Primitive, Material,
                ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER, FLOAT, UNSIGNED_SHORT, VEC3
            )

            def create_box_geometry(size=1.0, position=(0, 0, 0)):
                """Generate vertex and index data for a 3D box with specified size and position."""
                size = np.array(size if isinstance(size, (list, tuple)) else [size]*3)
                position = np.array(position)

                # Define cube faces with normals and vertex positions (local coordinates)
                faces = [
                    {  # Front (Z+)
                        "normal": [0, 0, 1],
                        "vertices": [
                            [0.5, 0.5, 0.5], [-0.5, 0.5, 0.5], 
                            [-0.5, -0.5, 0.5], [0.5, -0.5, 0.5]
                        ]
                    },
                    {  # Back (Z-)
                        "normal": [0, 0, -1],
                        "vertices": [
                            [0.5, 0.5, -0.5], [0.5, -0.5, -0.5],
                            [-0.5, -0.5, -0.5], [-0.5, 0.5, -0.5]
                        ]
                    },
                    {  # Left (X-)
                        "normal": [-1, 0, 0],
                        "vertices": [
                            [-0.5, 0.5, 0.5], [-0.5, 0.5, -0.5],
                            [-0.5, -0.5, -0.5], [-0.5, -0.5, 0.5]
                        ]
                    },
                    {  # Right (X+)
                        "normal": [1, 0, 0],
                        "vertices": [
                            [0.5, 0.5, 0.5], [0.5, -0.5, 0.5],
                            [0.5, -0.5, -0.5], [0.5, 0.5, -0.5]
                        ]
                    },
                    {  # Top (Y+)
                        "normal": [0, 1, 0],
                        "vertices": [
                            [-0.5, 0.5, 0.5], [0.5, 0.5, 0.5],
                            [0.5, 0.5, -0.5], [-0.5, 0.5, -0.5]
                        ]
                    },
                    {  # Bottom (Y-)
                        "normal": [0, -1, 0],
                        "vertices": [
                            [-0.5, -0.5, 0.5], [-0.5, -0.5, -0.5],
                            [0.5, -0.5, -0.5], [0.5, -0.5, 0.5]
                        ]
                    },
                ]

                vertices = []
                indices = []
                vertex_idx = 0

                for face in faces:
                    normal = np.array(face["normal"])
                    # Generate face vertices with positions and normals
                    face_vertices = []
                    for vertex in face["vertices"]:
                        local_pos = np.array(vertex) * (size / 2)
                        world_pos = local_pos + position
                        face_vertices.append(np.concatenate([world_pos, normal]))

                    # Add vertices to main list
                    vertices.extend(face_vertices)

                    # Generate indices for two triangles
                    indices.extend([
                        vertex_idx, vertex_idx+1, vertex_idx+2,
                        vertex_idx, vertex_idx+2, vertex_idx+3
                    ])
                    vertex_idx += 4

                return np.array(vertices, dtype=np.float32), np.array(indices, dtype=np.uint16)

            def create_gltf(vertices, indices, filename="box.gltf"):
                """Create GLTF2 structure and save files."""
                gltf = GLTF2()

                # Create buffer with combined vertex + index data
                vertex_bytes = vertices.tobytes()
                index_bytes = indices.tobytes()
                buffer_data = vertex_bytes + index_bytes

                # Main buffer
                buffer = Buffer()
                buffer.byteLength = len(buffer_data)
                buffer.uri = filename.replace(".gltf", ".bin")
                gltf.buffers.append(buffer)

                # Buffer Views
                # Vertex data view
                bv_vertex = BufferView()
                bv_vertex.buffer = 0
                bv_vertex.byteOffset = 0
                bv_vertex.byteLength = len(vertex_bytes)
                bv_vertex.target = ARRAY_BUFFER
                bv_vertex.byteStride = 24  # 3 pos + 3 normal * 4 bytes
                gltf.bufferViews.append(bv_vertex)

                # Index data view
                bv_index = BufferView()
                bv_index.buffer = 0
                bv_index.byteOffset = len(vertex_bytes)
                bv_index.byteLength = len(index_bytes)
                bv_index.target = ELEMENT_ARRAY_BUFFER
                gltf.bufferViews.append(bv_index)

                # Accessors
                positions = vertices[:, :3]
                pos_min = positions.min(axis=0).tolist()
                pos_max = positions.max(axis=0).tolist()

                # Position accessor
                acc_pos = Accessor()
                acc_pos.bufferView = 0
                acc_pos.byteOffset = 0
                acc_pos.componentType = FLOAT
                acc_pos.count = len(vertices)
                acc_pos.type = VEC3
                acc_pos.min = pos_min
                acc_pos.max = pos_max
                gltf.accessors.append(acc_pos)

                # Normal accessor
                acc_norm = Accessor()
                acc_norm.bufferView = 0
                acc_norm.byteOffset = 12  # Start after position (3 floats * 4 bytes)
                acc_norm.componentType = FLOAT
                acc_norm.count = len(vertices)
                acc_norm.type = VEC3
                gltf.accessors.append(acc_norm)

                # Index accessor
                acc_idx = Accessor()
                acc_idx.bufferView = 1
                acc_idx.byteOffset = 0
                acc_idx.componentType = UNSIGNED_SHORT
                acc_idx.count = len(indices)
                acc_idx.type = "SCALAR"
                gltf.accessors.append(acc_idx)

                # Material
                material = Material()
                material.pbrMetallicRoughness = {
                    "baseColorFactor": [0.5, 0.5, 0.5, 1.0],
                    "metallicFactor": 0.0,
                    "roughnessFactor": 0.5
                }
                gltf.materials.append(material)

                # Mesh
                primitive = Primitive()
                primitive.attributes.POSITION = 0
                primitive.attributes.NORMAL = 1
                primitive.indices = 2
                primitive.material = 0
                primitive.mode = 4  # TRIANGLES

                mesh = Mesh()
                mesh.primitives = [primitive]
                gltf.meshes.append(mesh)

                # Node
                node = Node()
                node.mesh = 0
                gltf.nodes.append(node)

                # Scene
                scene = Scene()
                scene.nodes = [0]
                gltf.scenes.append(scene)
                gltf.scene = 0

                # Save files
                gltf.save(filename)
                with open(buffer.uri, "wb") as f:
                    f.write(buffer_data)

            if __name__ == "__main__":
                vertices, indices = create_box_geometry()
                create_gltf(vertices, indices)
        '''
        
    def compile_prompt(self, question):
        prompt = ChatPromptTemplate(
            [
                (
                    "system",
                    self.code_generation_prompt
                ),
                ("human", "{question}"),
            ]
        )
        
        chain = prompt | self.model
        
        return chain
    
    def generate_code(self, question):
        prompt = self.compile_prompt(question)
        
        response = prompt.invoke({
            "example_code": self.example_code,
            "question": question
        })
        
        code = response.content
        
        cleaned_code = self.clean_response(code)
        
        self.save_to_file(cleaned_code)
    
    def save_to_file(self, contents):
        with open(self.file_path, "w", encoding="utf-8") as f:
            f.write(contents)
        
    def clean_response(self, response):
        # Remove the triple backticks and `python` from the beginning and end
        cleaned_response = re.sub(r"^```python\s*|\s*```$", "", response, flags=re.MULTILINE)
        return cleaned_response.strip()
            
code_agent = CodeAgent('./3d_cube.py')
code_agent.generate_code("Create a Cylinder Defined by circular top and bottom faces with connecting side faces.")