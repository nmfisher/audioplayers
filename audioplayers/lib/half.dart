import 'dart:typed_data';

class Half {
  static Float32List ToFloat32(ByteData buffer) {

    var f32Buffer = ByteData(buffer.lengthInBytes * 2);
    
    for(int i = 0; i < buffer.lengthInBytes; i+=2) {
        var half = buffer.getUint16(i, Endian.little);     
        // var half = 0xF200;
        // get sign by AND 0x800
        var sign = half & 0x8000;
        // assert(sign == 0x8000);
        // LS sign by 16 bits
        sign = sign << 16;

        // mask out sign bit/mantissa by AND 0x7c00 (0111 1100 0000 0000)  0111 1100 0000 0000
        var exp = half & 0x7c00;
        // assert(exp == 0x7000);
       
        // convert exp from 5-bit offset-binary to 8-bit offset-binary by
        // 1) subtracting 15 (0xF) to get true 5-bit exponent
        // 2) adding 127 (0x7F) to get stored 8-bit exponent)
        exp = exp >> 10;
        exp -= 0xF;
        // assert(exp == 0xD);
        // assert(0xD + 0x7F == 0x8C);
        exp += 0x7F;
        
        // assert(exp == 0x8C);
        // LS exp by 23
        exp = exp << 23;
        

        // mask out sign/exp by AND 0x03FF (0000 0011 1111 1111)
        var mant = half & 0x03FF;
        // assert(mant == 0x200);
        // convert mant from 10-bit offset-binary to 23-bit offset-binary by shifting left 13
        mant = mant << 13;
        
        // assert(sign == 0x80000000);
        // assert(exp ==  0x46000000);
        // assert(mant == 0x400000);
        // print(sign);
        // print(exp);
        // print(mant);
        // assert(sign + exp + mant == 0xc6400000);
        //print(sign + exp + mant);
        f32Buffer.setInt32(i * 2, sign + exp + mant, Endian.little);
        // f32Buffer.setInt32(i*2, 0xC6400800, Endian.little);
      }
      return Float32List.view(f32Buffer.buffer);
  }
}