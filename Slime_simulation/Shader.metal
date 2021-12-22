//
//  Shader.metal
//  Slime_simulation
//
//  Created by Edo Vay on 22/12/21.
//

#include <metal_stdlib>
using namespace metal;

struct Particle{
    float4 color;
    float2 position;
    float angle;
};

float rand(int x, int y, int z)
{
    int seed = x + y * 57 + z * 241;
    seed= (seed<< 13) ^ seed;
    return (( 1.0 - ( (seed * (seed * seed * 15731 + 789221) + 1376312589) & 2147483647) / 1073741824.0f) + 1.0f) / 2.0f;
}

uint hash(uint state){
    state ^= 2747636419u;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    
    return state;
}


kernel void clear_pass_func(texture2d<half, access::read_write> tex [[ texture(0) ]],
                            uint2 id [[ thread_position_in_grid ]]){
    
    //MARK: media per sfumare la scia
    half4 sum = 0;
    sum +=tex.read(id + uint2(1, 0));
    sum +=tex.read(id - uint2(1, 0));
    sum +=tex.read(id + uint2(0, 1));
    sum +=tex.read(id - uint2(0, 1));
    sum += tex.read(id);
    
    half4 color = sum/(5.3);
    if (abs(color.x) + abs(color.y) + abs(color.z) < 0.15)
    {
        color = half4(0, 0, 0, 1);
    }
    tex.write(color, id);
    
}

kernel void blur_pass_func(texture2d<half, access::read_write> tex [[ texture(0) ]],
                            uint2 id [[ thread_position_in_grid ]]){
    half4 sum = 0;
    int sensor_size = 1;
    for (int offset_x = -sensor_size; offset_x <= sensor_size; offset_x ++)
    {
        for (int offset_y = -sensor_size; offset_y <= sensor_size; offset_y ++)
        {
            int2 pos = int2(id) + int2(offset_x, offset_y);
            sum += tex.read(uint2(pos));
        }
    }
    
    half4 color = sum/((sensor_size*2 +1)*(sensor_size*2 +1));
    if (abs(color.x) + abs(color.y) + abs(color.z) < 0.05)
    {
        //color = half4(0, 0, 0, 1);
    }
    tex.write(color, id);
}

kernel void draw_dots_func(device Particle *particles [[ buffer(0) ]],
                           texture2d<half, access::read_write> tex [[ texture(0) ]],
                           uint id [[ thread_position_in_grid ]]){
    
    float width = tex.get_width();
    float height = tex.get_height();
    
    Particle particle;
    particle = particles[id];
    
    float2 position = particle.position;
    float angle = particle.angle;
    
    //MARK: ADD sensor code
    //ampiezza vedute
    const float sensor_angle = M_PI_F/6;
    //capacità di cambiare direzione
    const float turn_angle = M_PI_F/15;
    //piccolo o grande
    const int sensor_size = 1;
    //lungimiranza
    const uint sensor_distance = 10;
    //
    const float stear_randomnes = 1;
    int color1 = 2;
    int color2 = 0;
    if (particle.color.x > 0)
    {
        color1 = 0;
        color2 = 2;
    }
    
    //Left sensor
    float left_sum = 0;
    int2 l_sens_pos = int2(position + sensor_distance * float2(cos(angle + sensor_angle), sin(angle + sensor_angle)));
    for (int offset_x = -sensor_size; offset_x <= sensor_size; offset_x ++)
    {
        for (int offset_y = -sensor_size; offset_y <= sensor_size; offset_y ++)
        {
            int2 pos = l_sens_pos + int2(offset_x, offset_y);
            left_sum += tex.read(uint2(pos))[color1];
            //left_sum -= tex.read(uint2(pos))[color2];
        }
    }
    
    //Right sensor
    float right_sum = 0;
    int2 r_sens_pos = int2(position + sensor_distance * float2(cos(angle - sensor_angle), sin(angle - sensor_angle)));
    for (int offset_x = -sensor_size; offset_x <= sensor_size; offset_x ++)
    {
        for (int offset_y = -sensor_size; offset_y <= sensor_size; offset_y ++)
        {
            int2 pos = r_sens_pos + int2(offset_x, offset_y);
            right_sum += tex.read(uint2(pos))[color1];
            //right_sum -= tex.read(uint2(pos))[color2];
        }
    }
    
    //Center sensor
    float center_sum = 0;
    int2 c_sens_pos = int2(position + sensor_distance * float2(cos(angle), sin(angle)));
    for (int offset_x = -sensor_size; offset_x <= sensor_size; offset_x ++)
    {
        for (int offset_y = -sensor_size; offset_y <= sensor_size; offset_y ++)
        {
            int2 pos = c_sens_pos + int2(offset_x, offset_y);
            center_sum += tex.read(uint2(pos))[color1];
            //center_sum -= tex.read(uint2(pos))[color2];
        }
    }
    const float max_sudo_random = 4294967295;
    float random = hash(uint(position.x + position.y * width))/max_sudo_random;
    //float random = rand(position.x, position.y, angle);
    random = cos(random * 3.1415);
    
    const float acc = 0.41;
    if (left_sum > center_sum && left_sum > right_sum)
    {
        angle += turn_angle - turn_angle  * stear_randomnes * random;
        
        position += (1 + left_sum * acc) * float2(cos(angle), sin(angle));
    }else if (right_sum > center_sum && right_sum > left_sum)
    {
        angle -= turn_angle + turn_angle * stear_randomnes * random;
        
        position += (1 + right_sum * acc) * float2(cos(angle), sin(angle));
    }else{
        angle = angle + random * stear_randomnes * 0.1;
        
        position += (1 + center_sum * acc) * float2(cos(angle), sin(angle));
    }
    
    //position += float2(cos(angle), sin(angle));
    
    
    //MARK: Update position of particle
    if(position.x < 0 || position.x > width) angle = M_PI_F - angle;
    if(position.y < 0 || position.y > height) angle *= -1;
    
    particle.position = position;
    
    particle.angle = angle;
    
    particles[id] = particle;
    
    uint2 texturePosition = uint2(position.x, position.y);
    half4 col = half4(particle.color.r, particle.color.g, particle.color.b, 1);
    tex.write(col, texturePosition);
    //tex.write(col, texturePosition + uint2(1,0));
    //tex.write(col, texturePosition + uint2(0,1));
    //tex.write(col, texturePosition - uint2(1,0));
    //tex.write(col, texturePosition - uint2(0,1));
}
