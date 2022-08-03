func.func @simple_mul(%arg0: tensor<1024xf32>, %arg1: tensor<1024xf32>) -> tensor<1024xf32>
{
  %0 = "mhlo.multiply"(%arg0, %arg1) : (tensor<1024xf32>, tensor<1024xf32>) -> tensor<1024xf32>
  return %0 : tensor<1024xf32>
}
