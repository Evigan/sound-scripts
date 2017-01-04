SOX "%1" "%2" ^
  --show-progress ^
  remix - ^
  highpass 100 ^
  norm ^
  compand 0.3,1 6:-70,-60,-20 -5 -90 0.2 ^
  vad -T 0.6 -p 0.2 -t 5 ^
  fade 0.1 ^
  reverse ^
  vad -T 0.6 -p 0.2 -t 5 ^
  fade 0.1 ^
  reverse ^
  norm -0.5 ^
  rate -v 22050
