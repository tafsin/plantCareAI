import 'local_plant_image_store.dart';
import 'local_plant_image_store_web.dart'
    if (dart.library.io) 'local_plant_image_store_io.dart'
    as platform;

LocalPlantImageStore createLocalPlantImageStore() =>
    platform.createLocalPlantImageStore();
